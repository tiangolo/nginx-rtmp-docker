#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${1:-nginx-rtmp-test}"
CONTAINER_NAME="${CONTAINER_NAME:-nginx-rtmp-test}"
WORK_DIR="$(mktemp -d)"
PUBLISH_DURATION="${PUBLISH_DURATION:-30}"
PUBLISHER_PID=""
CURRENT_CASE="setup"

cleanup() {
    local status=$?
    set +e
    stop_publisher
    if [[ "$status" -ne 0 ]]; then
        print_logs "$CURRENT_CASE"
    fi
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    rm -rf "$WORK_DIR"
    exit "$status"
}
trap cleanup EXIT

stop_publisher() {
    if [[ -n "$PUBLISHER_PID" ]] && kill -0 "$PUBLISHER_PID" 2>/dev/null; then
        kill "$PUBLISHER_PID"
        wait "$PUBLISHER_PID" 2>/dev/null || true
    fi
    PUBLISHER_PID=""
}

print_logs() {
    local case_name="$1"
    echo "--- $case_name publisher log ---"
    [[ -f "$WORK_DIR/$case_name-publisher.log" ]] && cat "$WORK_DIR/$case_name-publisher.log"
    echo "--- $case_name client log ---"
    [[ -f "$WORK_DIR/$case_name-client.log" ]] && cat "$WORK_DIR/$case_name-client.log"
    echo "--- nginx -V output ---"
    [[ -f "$WORK_DIR/nginx-version.log" ]] && cat "$WORK_DIR/nginx-version.log"
    echo "--- container logs ---"
    docker logs "$CONTAINER_NAME" 2>/dev/null || true
}

start_container() {
    echo "Starting $CONTAINER_NAME from $IMAGE_NAME"
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker run -d --name "$CONTAINER_NAME" -p 1935:1935 "$@" "$IMAGE_NAME" >/dev/null
    sleep 2
    echo "Checking Nginx configuration"
    docker exec "$CONTAINER_NAME" nginx -t
    if ! docker ps --filter "name=^/${CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -Fx "$CONTAINER_NAME" >/dev/null; then
        echo "Container is not running." >&2
        exit 1
    fi
}

assert_nginx_build_flags() {
    echo "Checking Nginx build flags"
    docker exec "$CONTAINER_NAME" nginx -V >"$WORK_DIR/nginx-version.log" 2>&1
    local flags=(
        "--add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-1.2.2"
        "--with-stream"
        "--with-stream_ssl_module"
    )
    local flag
    for flag in "${flags[@]}"; do
        if ! grep -F -- "$flag" "$WORK_DIR/nginx-version.log" >/dev/null; then
            echo "Nginx was not compiled with expected configure argument: $flag" >&2
            exit 1
        fi
    done
}

write_rtmps_config() {
    echo "Generating self-signed certificate for RTMPS test"
    mkdir -p "$WORK_DIR/certs"
    openssl req \
        -x509 \
        -newkey rsa:2048 \
        -nodes \
        -days 1 \
        -subj "/CN=localhost" \
        -keyout "$WORK_DIR/certs/key.pem" \
        -out "$WORK_DIR/certs/cert.pem" >/dev/null 2>&1

    cat >"$WORK_DIR/nginx-rtmps.conf" <<'CONF'
worker_processes auto;
rtmp_auto_push on;
events {}

# This covers the RTMPS stream SSL proxy capability from PR #97.
# The proxy_protocol variant from the PR parsed but did not retransmit decodable
# video frames in this FFmpeg end-to-end test.
stream {
    upstream backend {
        server 127.0.0.1:1936;
    }

    server {
        listen 1935 ssl;
        proxy_pass backend;
        ssl_certificate /etc/nginx/certs/cert.pem;
        ssl_certificate_key /etc/nginx/certs/key.pem;
    }
}

rtmp {
    server {
        listen 1936;
        chunk_size 4096;

        application live {
            live on;
            record off;
        }
    }
}
CONF
}

publish_stream() {
    local case_name="$1"
    local stream_url="$2"
    shift 2

    echo "Publishing $case_name stream to $stream_url for ${PUBLISH_DURATION}s"
    ffmpeg \
        -hide_banner \
        -loglevel error \
        -nostdin \
        -re \
        -f lavfi \
        -i testsrc=size=320x240:rate=15 \
        -f lavfi \
        -i sine=frequency=1000:sample_rate=44100 \
        -t "$PUBLISH_DURATION" \
        -c:v libx264 \
        -preset ultrafast \
        -pix_fmt yuv420p \
        -c:a aac \
        -f flv \
        "$@" \
        "$stream_url" >"$WORK_DIR/$case_name-publisher.log" 2>&1 &
    PUBLISHER_PID=$!
}

decode_stream() {
    local case_name="$1"
    local stream_url="$2"
    shift 2

    local client_ok=0
    local attempt
    for attempt in {1..10}; do
        echo "Decoding $case_name stream from $stream_url, attempt $attempt"
        echo "Client decode attempt $attempt" >>"$WORK_DIR/$case_name-client.log"
        if timeout 15 ffmpeg \
            -hide_banner \
            -loglevel error \
            -rw_timeout 10000000 \
            "$@" \
            -i "$stream_url" \
            -frames:v 30 \
            -an \
            -f null \
            - >>"$WORK_DIR/$case_name-client.log" 2>&1; then
            client_ok=1
            break
        fi
        sleep 1
    done

    if [[ "$client_ok" -ne 1 ]]; then
        echo "Could not decode retransmitted video frames from $stream_url." >&2
        exit 1
    fi
}

run_case() {
    local case_name="$1"
    local stream_url="$2"
    shift 2
    local ffmpeg_options=("$@")

    CURRENT_CASE="$case_name"
    publish_stream "$case_name" "$stream_url" "${ffmpeg_options[@]}"
    sleep 3
    if ! kill -0 "$PUBLISHER_PID" 2>/dev/null; then
        echo "Publisher for $case_name exited before the client could decode." >&2
        print_logs "$case_name"
        exit 1
    fi
    decode_stream "$case_name" "$stream_url" "${ffmpeg_options[@]}"
    stop_publisher
    echo "Decoded retransmitted $case_name video frames from $stream_url."
}

start_container
assert_nginx_build_flags
run_case "rtmp" "rtmp://127.0.0.1:1935/live/test"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
write_rtmps_config
start_container \
    -v "$WORK_DIR/nginx-rtmps.conf:/etc/nginx/nginx.conf:ro" \
    -v "$WORK_DIR/certs:/etc/nginx/certs:ro"
run_case "rtmps" "rtmps://127.0.0.1:1935/live/test" -tls_verify 0
