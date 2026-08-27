#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${ROOT_DIR}"

mkdir -p build dist
cat > build/build.env <<EOF
BOOTSTRAP_PYTHON=${BOOTSTRAP_PYTHON:-python3.11}
AGENT_EXTRAS=${AGENT_EXTRAS:-all,messaging,matrix,slack,dingtalk,feishu,wecom,teams,anthropic,exa,firecrawl,parallel-web,fal,modal,daytona,vercel,hindsight,bedrock,vertex,azure-identity,youtube}
EOF

rm -f build/upstream.env
if [ "${USE_LATEST_RELEASES:-0}" = 1 ]; then
  bash ./scripts/resolve-releases.sh
fi

bash ./scripts/fetch-upstream.sh
bash ./scripts/bundle-runtime.sh
bash ./scripts/build-agent.sh
bash ./scripts/build-studio.sh
bash ./scripts/verify-runtime.sh

test -f fpk/manifest
test -f fpk/config/privilege
test -f fpk/config/resource
test -f fpk/ICON.PNG
test -f fpk/ICON_256.PNG
if ! command -v fnpack >/dev/null 2>&1; then
  mkdir -p build/tools
  curl --fail --location --retry 3 \
    --output build/tools/fnpack \
    "${FNPACK_URL:-https://static2.fnnas.com/fnpack/fnpack-1.2.3-linux-amd64}"
  chmod 0755 build/tools/fnpack
  FNPACK="${ROOT_DIR}/build/tools/fnpack"
else
  FNPACK=$(command -v fnpack)
fi

rm -f dist/*.fpk dist/*.sha256 fpk/*.fpk
(
  cd "${ROOT_DIR}/fpk"
  "${FNPACK:-fnpack}" build --directory "${ROOT_DIR}/fpk"
)
FPK=$(find "${ROOT_DIR}/fpk" -maxdepth 1 -type f -name '*.fpk' -print -quit)
test -n "${FPK}"
mv "${FPK}" dist/
FPK_NAME=$(basename "${FPK}")
sha256sum "dist/${FPK_NAME}" > "dist/${FPK_NAME}.sha256"
printf '%s\n' "Built dist/${FPK_NAME}"
