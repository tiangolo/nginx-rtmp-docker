#!/usr/bin/env bash
set -Eeuo pipefail

STREAM_URL="${1:-rtmp://127.0.0.1:1935/live/test}"

ffmpeg \
    -hide_banner \
    -re \
    -f lavfi \
    -i testsrc=size=640x360:rate=30 \
    -f lavfi \
    -i sine=frequency=1000:sample_rate=44100 \
    -c:v libx264 \
    -preset ultrafast \
    -pix_fmt yuv420p \
    -c:a aac \
    -f flv \
    "$STREAM_URL"
