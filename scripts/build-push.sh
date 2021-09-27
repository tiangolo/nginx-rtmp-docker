#!/usr/bin/env bash

set -e

use_tag="tiangolo/nginx-rtmp:$NAME"
use_dated_tag="${use_tag}-$(date -I)"

bash scripts/docker-login.sh

docker buildx build -t "$use_tag" --platform=linux/amd64,linux/arm64,linux/arm . --push

docker buildx build -t "$use_dated_tag" --platform=linux/amd64,linux/arm64,linux/arm . --push
