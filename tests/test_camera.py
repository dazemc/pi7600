import numpy as np

from Camera import FacialRecognition


def test_recognition_disables_when_models_are_missing(tmp_path):
    recognition = FacialRecognition(
        detector_path=str(tmp_path / "missing-detector.onnx"),
        recognizer_path=str(tmp_path / "missing-recognizer.onnx"),
        embeddings_dir=str(tmp_path / "embeddings"),
    )
    assert recognition.enabled is False
    frame = np.zeros((10, 10, 3), dtype=np.uint8)
    assert recognition.recognize_face(frame) is frame
    assert recognition.enroll("alice", frame) is False
