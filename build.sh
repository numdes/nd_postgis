#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ND_POSTGIS_IMAGE_NAME="${ND_POSTGIS_IMAGE_NAME:-numdes/nd_postgis:0.1.0}"

docker build \
    --tag "$ND_POSTGIS_IMAGE_NAME" \
    --file ./Dockerfile \
    .