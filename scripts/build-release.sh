#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

requested_agent_version=${AGENT_PACKAGE_VERSION:-}
requested_studio_version=${STUDIO_PACKAGE_VERSION:-}
source versions.lock

BUILD_TARGET=${BUILD_TARGET:-both}
case "$BUILD_TARGET" in
  agent|studio|both) ;;
  *) echo "BUILD_TARGET must be agent, studio, or both (got: $BUILD_TARGET)" >&2; exit 2 ;;
esac

validate_package_version() {
  local version=$1
  if [[ ! "$version" =~ ^[0-9]+\\.[0-9]+\\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Package version must look like 0.1.17 (got: $version)" >&2
    exit 2
  fi
}

resolve_package_version() {
  local target=$1
  local requested=$2
  local fallback=$3
  if [ -n "$requested" ]; then
    validate_package_version "$requested"
    printf '%s\\n' "$requested"
  else
    bash "${ROOT_DIR}/scripts/next-package-version.sh" "$target" "$fallback"
  fi
}

agent_package_version=
studio_package_version=
if [ "$BUILD_TARGET" = agent ] || [ "$BUILD_TARGET" = both ]; then
  agent_package_version=$(resolve_package_version agent "$requested_agent_version" "$AGENT_PACKAGE_VERSION")
fi
if [ "$BUILD_TARGET" = studio ] || [ "$BUILD_TARGET" = both ]; then
  studio_package_version=$(resolve_package_version studio "$requested_studio_version" "$STUDIO_PACKAGE_VERSION")
fi

export AGENT_PACKAGE_VERSION="$agent_package_version"
export STUDIO_PACKAGE_VERSION="$studio_package_version"

mkdir -p build dist
rm -rf build/agent-stage build/studio-stage build/agent-runtime-tree build/studio-runtime-tree build/upstream build/agent-runtime build/studio-runtime
rm -f dist/*.fpk dist/*.sha256 dist/SHA256SUMS dist/build-manifest.json
printf 'AGENT_EXTRAS=%s\\n' "${AGENT_EXTRAS:-all,messaging,matrix,slack,dingtalk,feishu,wecom,teams,anthropic,exa,firecrawl,parallel-web,fal,modal,daytona,vercel,hindsight,bedrock,vertex,azure-identity,youtube}" > build/build.env

if [ "${USE_LATEST_RELEASES:-0}" = 1 ]; then
  BUILD_TARGET="$BUILD_TARGET" ./scripts/resolve-releases.sh
fi
BUILD_TARGET="$BUILD_TARGET" ./scripts/fetch-upstream.sh

if [ "$BUILD_TARGET" = agent ] || [ "$BUILD_TARGET" = both ]; then
  ./scripts/bundle-agent-runtime.sh
  AGENT_PACKAGE_VERSION="$agent_package_version" PACKAGE_VERSION="$agent_package_version" ./scripts/build-agent-fpk.sh
fi
if [ "$BUILD_TARGET" = studio ] || [ "$BUILD_TARGET" = both ]; then
  ./scripts/bundle-studio-runtime.sh
  STUDIO_PACKAGE_VERSION="$studio_package_version" PACKAGE_VERSION="$studio_package_version" ./scripts/build-studio-fpk.sh
fi

./scripts/validate-fpk.sh
sha256sum dist/*.fpk > dist/SHA256SUMS

agent_upstream="$HERMES_AGENT_VERSION"
studio_upstream="$HERMES_STUDIO_VERSION"
agent_tag="$HERMES_AGENT_TAG"
studio_tag="$HERMES_STUDIO_TAG"
if [ -f build/upstream.env ]; then
  . build/upstream.env
  agent_upstream="${HERMES_AGENT_VERSION:-$agent_upstream}"
  studio_upstream="${HERMES_STUDIO_VERSION:-$studio_upstream}"
  agent_tag="${HERMES_AGENT_TAG:-$agent_tag}"
  studio_tag="${HERMES_STUDIO_TAG:-$studio_tag}"
fi

jq -n \
  --arg target "$BUILD_TARGET" \
  --arg agent_package "$agent_package_version" \
  --arg studio_package "$studio_package_version" \
  --arg agent_upstream "$agent_upstream" \
  --arg agent_tag "$agent_tag" \
  --arg studio_upstream "$studio_upstream" \
  --arg studio_tag "$studio_tag" \
  --arg contract "$INTEGRATION_CONTRACT_VERSION" \
  '{
    build_target: $target,
    architecture: "x86_64",
    fnos: "1.2",
    package_versions: {},
    upstream: {
      agent: {version: $agent_upstream, tag: $agent_tag},
      studio: {version: $studio_upstream, tag: $studio_tag}
    },
    hermes_agent: {version: $agent_upstream, tag: $agent_tag},
    hermes_studio: {version: $studio_upstream, tag: $studio_tag},
    integration_contract: $contract
  }
  | if ($target == "agent" or $target == "both")
    then .package_versions.agent = $agent_package
    else .
    end
  | if ($target == "studio" or $target == "both")
    then .package_versions.studio = $studio_package
    else .
    end
  | if $target == "agent"
    then .package_version = $agent_package
    elif $target == "studio"
    then .package_version = $studio_package
    else .
    end' > dist/build-manifest.json

echo "Built $BUILD_TARGET package(s):"
if [ -n "$agent_package_version" ]; then echo "  Hermes Agent $agent_package_version"; fi
if [ -n "$studio_package_version" ]; then echo "  Hermes Studio $studio_package_version"; fi
ls -lh dist/
