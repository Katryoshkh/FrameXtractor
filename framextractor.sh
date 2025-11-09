#!/bin/bash

echo "========================================================"
echo "         🎞️  FFmpeg Interactive Frame Extractor"
echo "========================================================"
echo

read -rp "Enter video file path: " INPUT
if [ ! -f "$INPUT" ]; then
    echo "❌ Error: File not found: $INPUT"
    exit 1
fi

INPUT_DIR=$(dirname "$INPUT")
OUTPUT_DIR="$INPUT_DIR/frames"
count=1
while [ -d "$OUTPUT_DIR" ]; do
    OUTPUT_DIR="$INPUT_DIR/frames($count)"
    count=$((count + 1))
done
mkdir -p "$OUTPUT_DIR"

read -rp "Enter FPS (frames per second) [default: 30]: " FPS
FPS=${FPS:-30}

read -rp "Choose image format (png/jpg) [default: png]: " FORMAT
FORMAT=${FORMAT:-png}
FORMAT="${FORMAT,,}"
if [[ "$FORMAT" != "png" && "$FORMAT" != "jpg" && "$FORMAT" != "jpeg" ]]; then
    echo "❌ Invalid format. Please choose 'png' or 'jpg'."
    exit 1
fi

QUALITY=""
if [[ "$FORMAT" == "jpg" || "$FORMAT" == "jpeg" ]]; then
    read -rp "Set JPEG quality (2–31, lower = better) [default: 2]: " QUALITY
    QUALITY=${QUALITY:-2}
    if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 2 ] || [ "$QUALITY" -gt 31 ]; then
        echo "❌ Invalid quality value. Must be between 2 and 31."
        exit 1
    fi
fi

echo
echo "💡 Tip: format scaling = width:height (example: 1280:-1 or -1:720)"
read -rp "Enter scaling (leave blank to keep original resolution): " SCALE

VF_FILTER="fps=$FPS"
if [ -n "$SCALE" ]; then
    if [[ "$SCALE" != *":"* ]]; then
        echo "❌ Invalid scaling format. Use width:height (e.g., 1280:-1)"
        exit 1
    fi
    VF_FILTER="$VF_FILTER,scale=$SCALE"
else
    VF_FILTER="$VF_FILTER,scale=iw:ih"
fi

read -rp "Enter output base name (default: frame): " BASE_NAME
BASE_NAME=${BASE_NAME:-frame}

PATTERN="${BASE_NAME}_%04d.$FORMAT"

echo
echo "========================================================"
echo "Input video : $INPUT"
echo "Output dir  : $OUTPUT_DIR"
echo "FPS         : $FPS"
echo "Format      : $FORMAT"
if [ -n "$SCALE" ]; then echo "Scale       : $SCALE (custom)"; else echo "Scale       : original (1:1)"; fi
if [ -n "$QUALITY" ]; then echo "Quality     : $QUALITY"; fi
echo "Output name : $PATTERN"
echo "========================================================"
read -rp "Proceed with extraction? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo
echo "▶️  Starting frame extraction..."
if [[ "$FORMAT" == "png" ]]; then
    ffmpeg -hide_banner -loglevel info -i "$INPUT" -vf "$VF_FILTER" \
           "$OUTPUT_DIR/$PATTERN"
else
    ffmpeg -hide_banner -loglevel info -i "$INPUT" -vf "$VF_FILTER" \
           -q:v "$QUALITY" "$OUTPUT_DIR/$PATTERN"
fi

echo
echo "✅ Extraction complete!"
echo "Frames saved in: $OUTPUT_DIR/"
echo "=========================================================="
