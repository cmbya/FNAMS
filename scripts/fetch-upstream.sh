#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
source "${ROOT_DIR}/build/upstream.env" 2>/dev/null || true
SRC_DIR="${ROOT_DIR}/build/upstream"
mkdir -p "$SRC_DIR"
rm -rf "${SRC_DIR}/hermes-agent" "${SRC_DIR}/hermes-studio" "${SRC_DIR}"/*.tar.gz
agent_archive="${SRC_DIR}/hermes-agent.tar.gz"
studio_archive="${SRC_DIR}/hermes-studio.tar.gz"
agent_url="https://codeload.github.com/nousresearch/hermes-agent/tar.gz/refs/tags/${HERMES_AGENT_TAG}"
studio_url="${STUDIO_ARCHIVE_URL:-https://github.com/EKKOLearnAI/hermes-studio/releases/download/${HERMES_STUDIO_TAG}/hermes-web-ui-${HERMES_STUDIO_VERSION}.tar.gz}"
curl --fail --location --retry 3 --output "$agent_archive" "$agent_url"
curl --fail --location --retry 3 --output "$studio_archive" "$studio_url"
mkdir -p "${SRC_DIR}/hermes-agent" "${SRC_DIR}/hermes-studio"
tar -xzf "$agent_archive" --strip-components=1 -C "${SRC_DIR}/hermes-agent"
tar -xzf "$studio_archive" --strip-components=1 -C "${SRC_DIR}/hermes-studio"
test -f "${SRC_DIR}/hermes-agent/pyproject.toml"
test -f "${SRC_DIR}/hermes-studio/bin/hermes-web-ui.mjs"
echo "Upstream sources staged at ${SRC_DIR}."

