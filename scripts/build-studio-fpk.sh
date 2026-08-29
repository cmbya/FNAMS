#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
STAGE="${ROOT_DIR}/build/studio-stage"
mkdir -p "${ROOT_DIR}/dist"
rm -rf "$STAGE"
cp -a "${ROOT_DIR}/apps/hermes-studio/." "$STAGE/"
cp -a "${ROOT_DIR}/build/studio-runtime-tree/app/." "$STAGE/app/"
install -d "$STAGE/app/ui/images"
"${ROOT_DIR}/scripts/render-svg-icon.sh" "${ROOT_DIR}/assets/hermes-studio.svg" 256 "$STAGE/app/ui/images/icon_256.png"
"${ROOT_DIR}/scripts/render-svg-icon.sh" "${ROOT_DIR}/assets/hermes-studio.svg" 64 "$STAGE/app/ui/images/icon_64.png"
"${ROOT_DIR}/scripts/render-svg-icon.sh" "${ROOT_DIR}/assets/hermes-studio.svg" 256 "$STAGE/ICON_256.PNG"
"${ROOT_DIR}/scripts/render-svg-icon.sh" "${ROOT_DIR}/assets/hermes-studio.svg" 64 "$STAGE/ICON.PNG"
chmod 0755 "$STAGE"/cmd/*
if [ -f "$STAGE/app/bin/hermes-studio-bridge-python" ]; then
  chmod 0755 "$STAGE/app/bin/hermes-studio-bridge-python"
fi
"${ROOT_DIR}/scripts/package-fpk.sh" \
  "$STAGE" "${ROOT_DIR}/dist/HermesStudio-${FPK_VERSION}-fnOS-x86_64.fpk"
