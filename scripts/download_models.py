#!/usr/bin/env python3
"""Download the optional OpenCV face models used by facial recognition.

The models are large binaries and are not committed to the repository. Run this
from the repository root after ``uv sync``:

    uv run python scripts/download_models.py
"""

from pathlib import Path
from urllib.request import urlretrieve

MODELS = {
    "face_detection_yunet_2023mar_int8bq.onnx": (
        "https://github.com/opencv/opencv_zoo/raw/main/models/"
        "face_detection_yunet/face_detection_yunet_2023mar_int8bq.onnx"
    ),
    "face_recognition_sface_2021dec.onnx": (
        "https://github.com/opencv/opencv_zoo/raw/main/models/"
        "face_recognition_sface/face_recognition_sface_2021dec.onnx"
    ),
}


def main() -> None:
    target = Path("ml")
    target.mkdir(parents=True, exist_ok=True)
    for name, url in MODELS.items():
        destination = target / name
        if destination.is_file():
            print(f"Skipping {destination} (already exists)")
            continue
        print(f"Downloading {name}...")
        urlretrieve(url, destination)
        print(f"Saved {destination}")


if __name__ == "__main__":
    main()
