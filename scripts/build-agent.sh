#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
source "${ROOT_DIR}/build/build.env" 2>/dev/null || true
source "${ROOT_DIR}/build/upstream.env" 2>/dev/null || true

SRC_DIR="${ROOT_DIR}/build/upstream/hermes-agent"
RUNTIME_DIR="${ROOT_DIR}/fpk/app/runtime/python"
AGENT_DIR="${ROOT_DIR}/fpk/app/hermes-agent"
BOOTSTRAP_PYTHON=${BOOTSTRAP_PYTHON:-python3.11}
UV_BIN=${UV_BIN:-uv}
AGENT_EXTRAS=${AGENT_EXTRAS:-all,messaging,matrix,slack,dingtalk,feishu,wecom,teams,anthropic,exa,firecrawl,parallel-web,fal,modal,daytona,vercel,hindsight,bedrock,vertex,azure-identity,youtube}

test -f "${SRC_DIR}/pyproject.toml"
rm -rf "${AGENT_DIR}"
mkdir -p "${RUNTIME_DIR}" "${AGENT_DIR}"
test -x "${RUNTIME_DIR}/bin/python3"
EXTRA_ARGS=()
IFS=',' read -r -a EXTRA_LIST <<< "${AGENT_EXTRAS}"
for extra in "${EXTRA_LIST[@]}"; do
  EXTRA_ARGS+=(--extra "${extra}")
done
"${UV_BIN}" export --locked --project "${SRC_DIR}" --format requirements.txt \
  --no-emit-project "${EXTRA_ARGS[@]}" \
  --output-file "${ROOT_DIR}/build/hermes-requirements.txt"
"${UV_BIN}" pip install --python "${RUNTIME_DIR}/bin/python3" --prefix "${RUNTIME_DIR}" \
  --requirement "${ROOT_DIR}/build/hermes-requirements.txt"
"${UV_BIN}" pip install --python "${RUNTIME_DIR}/bin/python3" --prefix "${RUNTIME_DIR}" \
  --no-deps "${SRC_DIR}"
ln -sf python3 "${RUNTIME_DIR}/bin/python"
cp -a "${SRC_DIR}/." "${AGENT_DIR}/"
printf '%s\n' "Hermes Agent ${HERMES_AGENT_VERSION} installed with extras [${AGENT_EXTRAS}]."
