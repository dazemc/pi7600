import asyncio
import logging
import threading
import time
from pathlib import Path

import cv2
import numpy as np
from fastapi import WebSocket

logger = logging.getLogger("uvicorn.pi7600")


class VideoCaptureThread:
    """Read frames from a camera in a background thread.

    The thread keeps only the latest JPEG frame so slow or multiple WebSocket
    clients cannot block the capture loop.
    """

    def __init__(self, index: int = -1, fps: int = 15) -> None:
        self.index = index
        self.fps = max(1, fps)
        self.cap: cv2.VideoCapture | None = None
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._frame: bytes | None = None

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return

        self.cap = cv2.VideoCapture(self.index, cv2.CAP_V4L2)
        if not self.cap.isOpened():
            self.cap.release()
            self.cap = cv2.VideoCapture(self.index)
        if not self.cap.isOpened():
            self.cap.release()
            self.cap = None
            raise RuntimeError(f"Unable to open camera index {self.index}")

        self._stop.clear()
        self._thread = threading.Thread(
            target=self._reader, name="video-capture", daemon=True
        )
        self._thread.start()

    def _reader(self) -> None:
        frame_interval = 1.0 / self.fps
        while not self._stop.is_set():
            started = time.monotonic()
            if self.cap is None:
                break
            ok, frame = self.cap.read()
            if not ok:
                time.sleep(0.05)
                continue
            encoded, buffer = cv2.imencode(".jpg", frame)
            if encoded:
                with self._lock:
                    self._frame = buffer.tobytes()
            remaining = frame_interval - (time.monotonic() - started)
            if remaining > 0:
                time.sleep(remaining)

    def get_frame(self) -> bytes | None:
        with self._lock:
            return self._frame

    def release(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=2)
            self._thread = None
        if self.cap is not None:
            self.cap.release()
            self.cap = None
        with self._lock:
            self._frame = None


class VideoStreamManager:
    """Track video WebSocket clients and broadcast frames safely."""

    def __init__(self) -> None:
        self.connections: list[WebSocket] = []
        self._lock = asyncio.Lock()
        self._capture: VideoCaptureThread | None = None
        self._fps = 15
        self._task: asyncio.Task | None = None

    async def add(self, websocket: WebSocket) -> None:
        async with self._lock:
            if websocket not in self.connections:
                self.connections.append(websocket)

    async def remove(self, websocket: WebSocket) -> None:
        async with self._lock:
            if websocket in self.connections:
                self.connections.remove(websocket)

    async def start(self, capture: VideoCaptureThread, fps: int) -> None:
        """Start the single broadcaster that feeds every connected client."""
        if self._task is not None and not self._task.done():
            return
        self._capture = capture
        self._fps = max(1, fps)
        self._task = asyncio.create_task(self._broadcast_loop())

    async def _broadcast_loop(self) -> None:
        interval = 1.0 / self._fps
        while True:
            frame = self._capture.get_frame() if self._capture is not None else None
            if frame is not None:
                await self.broadcast(frame)
            await asyncio.sleep(interval)

    async def broadcast(self, frame: bytes) -> None:
        async with self._lock:
            connections = list(self.connections)
        for websocket in connections:
            try:
                await websocket.send_bytes(frame)
            except Exception:
                await self.remove(websocket)

    async def stop(self) -> None:
        task = self._task
        self._task = None
        if task is not None:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
        self._capture = None
        await self.close_all()

    async def close_all(self) -> None:
        async with self._lock:
            connections = list(self.connections)
            self.connections.clear()
        for websocket in connections:
            try:
                await websocket.close()
            except Exception:
                pass


class FacialRecognition:
    """Face detection + embedding-based recognition using OpenCV.

    YuNet is used for detection and SFace for embeddings. The recognizer model
    is intentionally not committed to the repository; see
    ``scripts/download_models.py``.
    """

    def __init__(
        self,
        detector_path: str,
        recognizer_path: str,
        embeddings_dir: str,
        threshold: float = 0.363,
    ) -> None:
        self.threshold = threshold
        self.embeddings_dir = Path(embeddings_dir)
        self.enabled = False
        self.detector: cv2.FaceDetectorYN | None = None
        self.recognizer: cv2.FaceRecognizerSF | None = None
        self.known_faces: dict[str, np.ndarray] = {}

        try:
            if not Path(detector_path).is_file():
                raise FileNotFoundError(detector_path)
            if not Path(recognizer_path).is_file():
                raise FileNotFoundError(recognizer_path)
            self.detector = cv2.FaceDetectorYN.create(detector_path, "", (320, 320))
            self.recognizer = cv2.FaceRecognizerSF.create(recognizer_path, "")
            self.enabled = True
        except Exception as exc:
            logger.warning("Facial recognition disabled: %s", exc)

        self._load_known_faces()

    def _load_known_faces(self) -> None:
        self.known_faces = {}
        if not self.embeddings_dir.is_dir():
            return
        for path in sorted(self.embeddings_dir.glob("*.npy")):
            try:
                self.known_faces[path.stem] = np.load(path).flatten()
            except Exception as exc:
                logger.warning("Unable to load embedding %s: %s", path, exc)

    def detect_faces(self, frame: np.ndarray) -> np.ndarray | None:
        if not self.enabled or self.detector is None:
            return None
        height, width = frame.shape[:2]
        self.detector.setInputSize((width, height))
        _, faces = self.detector.detect(frame)
        return faces

    def get_embedding(self, frame: np.ndarray, face: np.ndarray) -> np.ndarray | None:
        if not self.enabled or self.recognizer is None:
            return None
        try:
            aligned = self.recognizer.alignCrop(frame, face)
            return self.recognizer.feature(aligned).flatten()
        except Exception as exc:
            logger.warning("Unable to compute face embedding: %s", exc)
            return None

    def identify(self, embedding: np.ndarray) -> str:
        best_name = "Unknown"
        best_score = -1.0
        embedding_norm = np.linalg.norm(embedding)
        if embedding_norm == 0:
            return best_name
        for name, known in self.known_faces.items():
            known_norm = np.linalg.norm(known)
            if known_norm == 0:
                continue
            score = float(np.dot(embedding, known) / (embedding_norm * known_norm))
            if score > best_score:
                best_score = score
                best_name = name
        return best_name if best_score >= self.threshold else "Unknown"

    def recognize_face(self, frame: np.ndarray) -> np.ndarray:
        faces = self.detect_faces(frame)
        if faces is None:
            return frame
        for face in faces:
            x, y, w, h = (int(value) for value in face[:4])
            embedding = self.get_embedding(frame, face)
            identity = self.identify(embedding) if embedding is not None else "Unknown"
            cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(
                frame,
                identity,
                (x, max(y - 10, 0)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.9,
                (0, 255, 0),
                2,
            )
        return frame

    def enroll(self, name: str, frame: np.ndarray) -> bool:
        faces = self.detect_faces(frame)
        if faces is None or len(faces) == 0:
            return False
        embedding = self.get_embedding(frame, faces[0])
        if embedding is None:
            return False
        self.embeddings_dir.mkdir(parents=True, exist_ok=True)
        path = self.embeddings_dir / f"{name}.npy"
        np.save(path, embedding)
        self.known_faces[name] = embedding
        return True
