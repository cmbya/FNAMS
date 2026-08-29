#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
OUT_DIR="${ROOT_DIR}/build/studio-runtime-tree/app"
WORK_DIR="${ROOT_DIR}/build/studio-runtime"
NODE_URL=${NODE_ARCHIVE_URL:-https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz}
rm -rf "$WORK_DIR" "${OUT_DIR}/runtime" "${OUT_DIR}/studio"
mkdir -p "$WORK_DIR" "${OUT_DIR}/runtime/node" "${OUT_DIR}/studio"
curl --fail --location --retry 3 --output "$WORK_DIR/node.tar.xz" "$NODE_URL"
tar -xJf "$WORK_DIR/node.tar.xz" --no-same-owner --strip-components=1 -C "${OUT_DIR}/runtime/node"
cp -a "${ROOT_DIR}/build/upstream/hermes-studio/." "${OUT_DIR}/studio/"
python3 "${ROOT_DIR}/scripts/patch-studio-runtime.py" "${OUT_DIR}/studio"
test -x "${OUT_DIR}/runtime/node/bin/node"
test -f "${OUT_DIR}/studio/bin/hermes-web-ui.mjs"
echo 'Studio release and Node runtime bundled.'
