#!/usr/bin/env bash
set -e

use_tag="tiangolo/nginx-rtmp:$NAME"

docker build -t "$use_tag" .
