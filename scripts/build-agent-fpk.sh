#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
STAGE="${ROOT_DIR}/build/agent-stage"
mkdir -p "${ROOT_DIR}/dist"
rm -rf "$STAGE"
cp -a "${ROOT_DIR}/apps/hermes-agent/." "$STAGE/"
cp -a "${ROOT_DIR}/build/agent-runtime-tree/app/." "$STAGE/app/"
install -d "$STAGE/app/ui/images"
convert "${ROOT_DIR}/assets/hermes-agent.svg" -resize 256x256 "$STAGE/app/ui/images/icon_256.png"
convert "${ROOT_DIR}/assets/hermes-agent.svg" -resize 64x64 "$STAGE/app/ui/images/icon_64.png"
convert "${ROOT_DIR}/assets/hermes-agent.svg" -resize 256x256 "$STAGE/ICON_256.PNG"
convert "${ROOT_DIR}/assets/hermes-agent.svg" -resize 64x64 "$STAGE/ICON.PNG"
chmod 0755 "$STAGE"/cmd/* "$STAGE"/app/bin/*
"${ROOT_DIR}/scripts/compact-agent-runtime.sh" "$STAGE/app" "$FPK_VERSION"
"${ROOT_DIR}/scripts/package-fpk.sh" \
  "$STAGE" "${ROOT_DIR}/dist/HermesAgent-${FPK_VERSION}-fnOS-x86_64.fpk"
