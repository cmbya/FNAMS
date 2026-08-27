#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
STAGE_DIR="${ROOT_DIR}/build/studio-release"
DEST_DIR="${ROOT_DIR}/fpk/app/hermes-studio"
ARCHIVE="${STAGE_DIR}/hermes-web-ui-${HERMES_STUDIO_VERSION}.tar.gz"
URL="https://github.com/EKKOLearnAI/hermes-studio/releases/download/${HERMES_STUDIO_TAG}/hermes-web-ui-${HERMES_STUDIO_VERSION}.tar.gz"

rm -rf "${STAGE_DIR}" "${DEST_DIR}"
mkdir -p "${STAGE_DIR}" "${DEST_DIR}"
curl --fail --location --retry 3 --output "${ARCHIVE}" "${URL}"
tar -xzf "${ARCHIVE}" --strip-components=1 -C "${DEST_DIR}"
test -f "${DEST_DIR}/bin/hermes-web-ui.mjs"
test -f "${DEST_DIR}/dist/server/index.js"
printf '%s\n' "Hermes Studio ${HERMES_STUDIO_VERSION} is ready."
