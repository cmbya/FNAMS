#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
STAGE="${ROOT_DIR}/build/agent-stage"
mkdir -p "${ROOT_DIR}/dist"
rm -rf "$STAGE"
cp -a "${ROOT_DIR}/apps/hermes-agent/." "$STAGE/"
cp -a "${ROOT_DIR}/build/agent-stage/app/." "$STAGE/app/"
install -d "$STAGE/app/ui/images"
convert "${ROOT_DIR}/assets/hermes-agent.svg" -resize 256x256 "$STAGE/app/ui/images/icon_256.png"
convert "${ROOT_DIR}/assets/hermes-agent.svg" -resize 64x64 "$STAGE/app/ui/images/icon_64.png"
chmod 0755 "$STAGE"/cmd/* "$STAGE"/app/bin/*
FNPACK=${FNPACK:-}
if [ -z "$FNPACK" ]; then FNPACK=$(command -v fnpack || true); fi
test -n "$FNPACK" || { echo 'fnpack is required.' >&2; exit 1; }
rm -f "$STAGE"/*.fpk
"$FNPACK" build --directory "$STAGE"
fpk=$(find "$STAGE" -maxdepth 1 -type f -name '*.fpk' -print -quit)
test -n "$fpk"
mv "$fpk" "${ROOT_DIR}/dist/HermesAgent-${FPK_VERSION}-fnOS-x86_64.fpk"

