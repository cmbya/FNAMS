#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/versions.lock"
source "${ROOT_DIR}/build/build.env" 2>/dev/null || true
source "${ROOT_DIR}/build/upstream.env" 2>/dev/null || true
SRC_DIR="${ROOT_DIR}/build/upstream/hermes-agent"
OUT_DIR="${ROOT_DIR}/build/agent-stage/app"
WORK_DIR="${ROOT_DIR}/build/agent-runtime"
PY_ROOT="${OUT_DIR}/runtime/python"
CHROME_ROOT="${OUT_DIR}/runtime/chromium"
AGENT_EXTRAS=${AGENT_EXTRAS:-all,messaging,matrix,slack,dingtalk,feishu,wecom,teams,anthropic,exa,firecrawl,parallel-web,fal,modal,daytona,vercel,hindsight,bedrock,vertex,azure-identity,youtube}
PY_URL=${PYTHON_STANDALONE_ARCHIVE_URL:-https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_STANDALONE_BUILD_DATE}/cpython-${PYTHON_STANDALONE_VERSION}+${PYTHON_STANDALONE_BUILD_DATE}-x86_64-unknown-linux-gnu-install_only.tar.gz}
CHROME_URL=${CHROMIUM_ARCHIVE_URL:-https://storage.googleapis.com/chrome-for-testing-public/${CHROMIUM_VERSION}/linux64/chrome-linux64.zip}
rm -rf "$WORK_DIR" "${OUT_DIR}/runtime"
mkdir -p "$WORK_DIR/python" "$PY_ROOT" "$CHROME_ROOT" "${OUT_DIR}/bin"
curl --fail --location --retry 3 --output "$WORK_DIR/python.tar.gz" "$PY_URL"
tar -xzf "$WORK_DIR/python.tar.gz" -C "$WORK_DIR/python"
python_bin=$(find "$WORK_DIR/python" -type f \( -path '*/bin/python3' -o -path '*/bin/python3.*' \) -perm -u+x | sort | head -n1)
test -n "$python_bin"
python_base=$(dirname "$(dirname "$python_bin")")
cp -a "$python_base/." "$PY_ROOT/"
test -x "$PY_ROOT/bin/python3"
command -v uv >/dev/null 2>&1 || { echo 'uv is required on the build host.' >&2; exit 1; }
cp "$(command -v uv)" "${OUT_DIR}/bin/uv"
chmod 0755 "${OUT_DIR}/bin/uv"
IFS=',' read -r -a extras <<< "$AGENT_EXTRAS"
extra_args=()
for extra in "${extras[@]}"; do extra_args+=(--extra "$extra"); done
uv export --locked --project "$SRC_DIR" --format requirements.txt --no-emit-project "${extra_args[@]}" --output-file "${WORK_DIR}/requirements.txt"
uv pip install --python "$PY_ROOT/bin/python3" --prefix "$PY_ROOT" --no-cache --requirement "${WORK_DIR}/requirements.txt"
HERMES_NIX_BUILD=1 uv pip install --python "$PY_ROOT/bin/python3" --prefix "$PY_ROOT" --no-cache --no-deps "$SRC_DIR"
cat >"${OUT_DIR}/bin/hermes-fnos" <<'EOF'
#!/bin/sh
set -eu
ROOT=${TRIM_APPDEST:?TRIM_APPDEST is required}/app
PY_ROOT=${ROOT}/runtime/python
export PYTHONHOME=${PY_ROOT}
export PYTHONPATH=${PY_ROOT}/lib/python3.11/site-packages${PYTHONPATH:+:${PYTHONPATH}}
export PATH=${ROOT}/bin:${PY_ROOT}/bin:${ROOT}/runtime/chromium:${PATH}
exec "${PY_ROOT}/bin/python3" "${PY_ROOT}/bin/hermes" "$@"
EOF
cat >"${OUT_DIR}/bin/hermes-python-fnos" <<'EOF'
#!/bin/sh
set -eu
ROOT=${TRIM_APPDEST:?TRIM_APPDEST is required}/app
PY_ROOT=${ROOT}/runtime/python
export PYTHONHOME=${PY_ROOT}
export PYTHONPATH=${PY_ROOT}/lib/python3.11/site-packages${PYTHONPATH:+:${PYTHONPATH}}
exec "${PY_ROOT}/bin/python3" "$@"
EOF
cat >"${OUT_DIR}/bin/hermes-uv-fnos" <<'EOF'
#!/bin/sh
set -eu
exec "${TRIM_APPDEST:?TRIM_APPDEST is required}/app/bin/uv" "$@"
EOF
chmod 0755 "${OUT_DIR}/bin/hermes-fnos" "${OUT_DIR}/bin/hermes-python-fnos" "${OUT_DIR}/bin/hermes-uv-fnos"
curl --fail --location --retry 3 --output "$WORK_DIR/chromium.zip" "$CHROME_URL"
unzip -q "$WORK_DIR/chromium.zip" -d "$CHROME_ROOT"
chrome_bin=$(find "$CHROME_ROOT" -type f \( -name chrome -o -name chromium \) -perm -u+x | head -n1)
test -n "$chrome_bin"
ln -sf "$chrome_bin" "${CHROME_ROOT}/chromium"
echo 'Agent runtime, dependencies and fallback Chromium bundled.'
