#!/bin/bash
# Download the optional ONNX face models used by facial recognition.
#
# The models are large binaries and are not all committed to the repository.
# Run this from the repository root:
#
#   ./scripts/download_models.sh [target-directory]
set -euo pipefail

TARGET="${1:-ml}"
mkdir -p "$TARGET"

download() {
    local name="$1"
    local url="$2"
    local destination="$TARGET/$name"
    if [ -f "$destination" ]; then
        echo "Skipping $destination (already exists)"
        return
    fi
    echo "Downloading $name..."
    curl --fail --location --output "$destination" "$url"
    echo "Saved $destination"
}

download \
    "face_detection_yunet_2023mar_int8bq.onnx" \
    "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar_int8bq.onnx"

download \
    "face_recognition_sface_2021dec.onnx" \
    "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx"
