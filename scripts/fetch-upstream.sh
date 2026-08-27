#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/build/upstream"
source "${ROOT_DIR}/versions.lock"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

fetch_repo() {
  local owner_repo=$1
  local tag=$2
  local name=$3
  local archive="${BUILD_DIR}/${name}.tar.gz"
  local target="${BUILD_DIR}/${name}"
  curl --fail --location --retry 3 --output "${archive}" \
    "https://codeload.github.com/${owner_repo}/tar.gz/refs/tags/${tag}"
  mkdir -p "${target}"
  tar -xzf "${archive}" --strip-components=1 -C "${target}"
}

fetch_repo "NousResearch/hermes-agent" "${HERMES_AGENT_TAG}" hermes-agent
fetch_repo "EKKOLearnAI/hermes-studio" "${HERMES_STUDIO_TAG}" hermes-studio-source

echo "Fetched Hermes Agent ${HERMES_AGENT_TAG} and Hermes Studio source ${HERMES_STUDIO_TAG}."
