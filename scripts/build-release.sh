#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"
source versions.lock
PACKAGE_VERSION=${PACKAGE_VERSION:-$FPK_VERSION}
if [[ ! "$PACKAGE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "PACKAGE_VERSION must look like 0.1.17 (got: $PACKAGE_VERSION)" >&2
  exit 2
fi
FPK_VERSION=$PACKAGE_VERSION
export PACKAGE_VERSION FPK_VERSION
BUILD_TARGET=${BUILD_TARGET:-both}
case "$BUILD_TARGET" in
  agent|studio|both) ;;
  *) echo "BUILD_TARGET must be agent, studio, or both (got: $BUILD_TARGET)" >&2; exit 2 ;;
esac
mkdir -p build dist
rm -rf build/agent-stage build/studio-stage build/agent-runtime-tree build/studio-runtime-tree build/upstream build/agent-runtime build/studio-runtime
rm -f dist/*.fpk dist/*.sha256 dist/SHA256SUMS dist/build-manifest.json
printf 'AGENT_EXTRAS=%s\n' "${AGENT_EXTRAS:-all,messaging,matrix,slack,dingtalk,feishu,wecom,teams,anthropic,exa,firecrawl,parallel-web,fal,modal,daytona,vercel,hindsight,bedrock,vertex,azure-identity,youtube}" > build/build.env
if [ "${USE_LATEST_RELEASES:-0}" = 1 ]; then ./scripts/resolve-releases.sh; fi
BUILD_TARGET="$BUILD_TARGET" ./scripts/fetch-upstream.sh
if [ "$BUILD_TARGET" = agent ] || [ "$BUILD_TARGET" = both ]; then
  ./scripts/bundle-agent-runtime.sh
  ./scripts/build-agent-fpk.sh
fi
if [ "$BUILD_TARGET" = studio ] || [ "$BUILD_TARGET" = both ]; then
  ./scripts/bundle-studio-runtime.sh
  ./scripts/build-studio-fpk.sh
fi
./scripts/validate-fpk.sh
sha256sum dist/*.fpk > dist/SHA256SUMS
agent_upstream=${HERMES_AGENT_VERSION}
studio_upstream=${HERMES_STUDIO_VERSION}
if [ -f build/upstream.env ]; then . build/upstream.env; agent_upstream=$HERMES_AGENT_VERSION; studio_upstream=$HERMES_STUDIO_VERSION; fi
cat > dist/build-manifest.json <<EOF
{
  "package_version": "${FPK_VERSION}",
  "architecture": "x86_64",
  "fnos": "1.2",
  "hermes_agent": {"version": "${agent_upstream}", "tag": "${HERMES_AGENT_TAG}"},
  "hermes_studio": {"version": "${studio_upstream}", "tag": "${HERMES_STUDIO_TAG}"},
  "integration_contract": "${INTEGRATION_CONTRACT_VERSION}"
}
EOF
echo "Built ${BUILD_TARGET} package(s) for ${FPK_VERSION}:"
ls -lh dist/
