#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${1:-nginx-rtmp-test}"
CONTAINER_NAME="${CONTAINER_NAME:-nginx-rtmp-test}"
STREAM_URL="${STREAM_URL:-rtmp://127.0.0.1:1935/live/test}"
WORK_DIR="$(mktemp -d)"
PUBLISHER_LOG="$WORK_DIR/publisher.log"
CLIENT_LOG="$WORK_DIR/client.log"
NGINX_VERSION_LOG="$WORK_DIR/nginx-version.log"
PUBLISHER_PID=""

cleanup() {
    local status=$?
    set +e
    if [[ -n "$PUBLISHER_PID" ]] && kill -0 "$PUBLISHER_PID" 2>/dev/null; then
        kill "$PUBLISHER_PID"
        wait "$PUBLISHER_PID" 2>/dev/null
    fi
    if [[ "$status" -ne 0 ]]; then
        echo "--- publisher log ---"
        [[ -f "$PUBLISHER_LOG" ]] && cat "$PUBLISHER_LOG"
        echo "--- client log ---"
        [[ -f "$CLIENT_LOG" ]] && cat "$CLIENT_LOG"
        echo "--- nginx -V output ---"
        [[ -f "$NGINX_VERSION_LOG" ]] && cat "$NGINX_VERSION_LOG"
        echo "--- container logs ---"
        docker logs "$CONTAINER_NAME" 2>/dev/null || true
    fi
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    rm -rf "$WORK_DIR"
    exit "$status"
}
trap cleanup EXIT

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -d --name "$CONTAINER_NAME" -p 1935:1935 "$IMAGE_NAME" >/dev/null
sleep 2

docker exec "$CONTAINER_NAME" nginx -t

docker exec "$CONTAINER_NAME" nginx -V >"$NGINX_VERSION_LOG" 2>&1
if ! grep -F -- "--add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-1.2.2" "$NGINX_VERSION_LOG" >/dev/null; then
    echo "Nginx was not compiled with the expected RTMP module configure argument." >&2
    exit 1
fi

if ! docker ps --filter "name=^/${CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -Fx "$CONTAINER_NAME" >/dev/null; then
    echo "Container is not running." >&2
    exit 1
fi

ffmpeg \
    -hide_banner \
    -loglevel error \
    -nostdin \
    -re \
    -f lavfi \
    -i testsrc=size=320x240:rate=15 \
    -f lavfi \
    -i sine=frequency=1000:sample_rate=44100 \
    -t 20 \
    -c:v libx264 \
    -preset ultrafast \
    -pix_fmt yuv420p \
    -c:a aac \
    -f flv \
    "$STREAM_URL" >"$PUBLISHER_LOG" 2>&1 &
PUBLISHER_PID=$!

client_ok=0
for attempt in {1..10}; do
    echo "Client decode attempt $attempt" >>"$CLIENT_LOG"
    if timeout 15 ffmpeg \
        -hide_banner \
        -loglevel error \
        -rw_timeout 10000000 \
        -i "$STREAM_URL" \
        -frames:v 30 \
        -an \
        -f null \
        - >>"$CLIENT_LOG" 2>&1; then
        client_ok=1
        break
    fi
    sleep 1
done

if [[ "$client_ok" -ne 1 ]]; then
    echo "Could not decode retransmitted video frames from $STREAM_URL." >&2
    exit 1
fi

echo "Decoded retransmitted RTMP video frames from $STREAM_URL."
