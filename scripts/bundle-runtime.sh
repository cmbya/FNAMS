#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
source "${ROOT_DIR}/build/build.env" 2>/dev/null || true
RUNTIME_DIR="${ROOT_DIR}/fpk/app/runtime"
WORK_DIR="${ROOT_DIR}/build/runtime"
NODE_ARCHIVE_URL=${NODE_ARCHIVE_URL:-"https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"}

: "${PYTHON_STANDALONE_ARCHIVE_URL:?Set PYTHON_STANDALONE_ARCHIVE_URL to a reviewed Python 3.11 x86_64 archive}"
: "${CHROMIUM_ARCHIVE_URL:?Set CHROMIUM_ARCHIVE_URL to a reviewed Chromium x86_64 archive}"

rm -rf "${WORK_DIR}" "${RUNTIME_DIR}/node" "${RUNTIME_DIR}/chromium" "${RUNTIME_DIR}/tools"
mkdir -p "${WORK_DIR}" "${RUNTIME_DIR}/node" "${RUNTIME_DIR}/chromium" "${RUNTIME_DIR}/tools"

curl --fail --location --retry 3 --output "${WORK_DIR}/node.tar.xz" "${NODE_ARCHIVE_URL}"
tar -xJf "${WORK_DIR}/node.tar.xz" --strip-components=1 -C "${RUNTIME_DIR}/node"

curl --fail --location --retry 3 --output "${WORK_DIR}/python.archive" "${PYTHON_STANDALONE_ARCHIVE_URL}"
mkdir -p "${WORK_DIR}/python"
tar -xf "${WORK_DIR}/python.archive" -C "${WORK_DIR}/python"
PYTHON_BIN=$(find "${WORK_DIR}/python" -type f -name python3 -perm -u+x | head -1)
test -n "${PYTHON_BIN}"
mkdir -p "${RUNTIME_DIR}/python/bin"
cp -a "$(dirname "${PYTHON_BIN}")/." "${RUNTIME_DIR}/python/bin/"
PYTHON_ROOT=$(dirname "$(dirname "${PYTHON_BIN}")")
if [ -d "${PYTHON_ROOT}/lib" ]; then
  cp -a "${PYTHON_ROOT}/lib" "${RUNTIME_DIR}/python/"
fi
if [ -d "${PYTHON_ROOT}/include" ]; then
  cp -a "${PYTHON_ROOT}/include" "${RUNTIME_DIR}/python/"
fi

curl --fail --location --retry 3 --output "${WORK_DIR}/chromium.archive" "${CHROMIUM_ARCHIVE_URL}"
tar -xf "${WORK_DIR}/chromium.archive" -C "${RUNTIME_DIR}/chromium"
CHROME_BIN=$(find "${RUNTIME_DIR}/chromium" -type f \( -name chromium -o -name chromium-browser -o -name chrome \) -perm -u+x | head -1)
test -n "${CHROME_BIN}"
ln -sf "${CHROME_BIN}" "${RUNTIME_DIR}/chromium/chromium"

if command -v uv >/dev/null 2>&1; then
  cp "$(command -v uv)" "${RUNTIME_DIR}/tools/uv"
fi
printf '%s\n' 'Node, Python and fallback Chromium were bundled into the FPK staging tree.'
