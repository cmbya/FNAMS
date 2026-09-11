#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

source versions.lock
requested_package_version=${PACKAGE_VERSION_INPUT:-}

BUILD_TARGET=${BUILD_TARGET:-agent}
case "$BUILD_TARGET" in
  agent|studio|both) ;;
  *) echo "BUILD_TARGET must be agent, studio, or both (got: $BUILD_TARGET)" >&2; exit 2 ;;
esac

validate_package_version() {
  local version=$1
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Package version must look like 0.1.17 (got: $version)" >&2
    exit 2
  fi
}

resolve_package_version() {
  local requested=$1
  local fallback=$2
  if [ -n "$requested" ]; then
    validate_package_version "$requested"
    printf '%s\n' "$requested"
  else
    bash "${ROOT_DIR}/scripts/next-package-version.sh" "$fallback"
  fi
}

package_version=$(resolve_package_version "$requested_package_version" "$PACKAGE_VERSION")
agent_package_version=
studio_package_version=
agent_built=false
studio_built=false
if [ "$BUILD_TARGET" = agent ] || [ "$BUILD_TARGET" = both ]; then
  agent_package_version="$package_version"
  agent_built=true
fi
if [ "$BUILD_TARGET" = studio ] || [ "$BUILD_TARGET" = both ]; then
  studio_package_version="$package_version"
  studio_built=true
fi

export PACKAGE_VERSION="$package_version"
export AGENT_PACKAGE_VERSION="$agent_package_version"
export STUDIO_PACKAGE_VERSION="$studio_package_version"

mkdir -p build dist
rm -rf build/agent-stage build/studio-stage build/agent-runtime-tree build/studio-runtime-tree build/upstream build/agent-runtime build/studio-runtime
rm -f build/upstream.env dist/*.fpk dist/*.sha256 dist/SHA256SUMS dist/build-manifest.json
printf 'AGENT_EXTRAS=%s\n' "${AGENT_EXTRAS:-all,messaging,matrix,slack,dingtalk,feishu,wecom,teams,anthropic,exa,firecrawl,parallel-web,fal,modal,daytona,vercel,hindsight,bedrock,vertex,azure-identity,youtube}" > build/build.env

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
agent_display="$HERMES_AGENT_DISPLAY_VERSION"
studio_upstream="$HERMES_STUDIO_VERSION"
studio_display="$HERMES_STUDIO_DISPLAY_VERSION"
agent_tag="$HERMES_AGENT_TAG"
studio_tag="$HERMES_STUDIO_TAG"
if [ -f build/upstream.env ]; then
  . build/upstream.env
  agent_upstream="${HERMES_AGENT_VERSION:-$agent_upstream}"
  agent_display="${HERMES_AGENT_DISPLAY_VERSION:-$agent_display}"
  studio_upstream="${HERMES_STUDIO_VERSION:-$studio_upstream}"
  studio_display="${HERMES_STUDIO_DISPLAY_VERSION:-$studio_display}"
  agent_tag="${HERMES_AGENT_TAG:-$agent_tag}"
  studio_tag="${HERMES_STUDIO_TAG:-$studio_tag}"
fi

jq -n \
  --arg target "$BUILD_TARGET" \
  --arg package "$package_version" \
  --arg agent_upstream "$agent_upstream" \
  --arg agent_display "$agent_display" \
  --arg agent_tag "$agent_tag" \
  --arg studio_upstream "$studio_upstream" \
  --arg studio_display "$studio_display" \
  --arg studio_tag "$studio_tag" \
  --arg contract "$INTEGRATION_CONTRACT_VERSION" \
  --argjson agent_built "$agent_built" \
  --argjson studio_built "$studio_built" \
  '{
    build_target: $target,
    architecture: "x86_64",
    fnos: "1.2",
    package_version: $package,
    package_versions: {},
    upstream: {
      agent: {version: $agent_upstream, display_version: $agent_display, tag: $agent_tag, built: $agent_built},
      studio: {version: $studio_upstream, display_version: $studio_display, tag: $studio_tag, built: $studio_built}
    },
    hermes_agent: {version: $agent_upstream, display_version: $agent_display, tag: $agent_tag, built: $agent_built},
    hermes_studio: {version: $studio_upstream, display_version: $studio_display, tag: $studio_tag, built: $studio_built},
    integration_contract: $contract
  }
  | if ($target == "agent" or $target == "both")
    then .package_versions.agent = $package
    else .
    end
  | if ($target == "studio" or $target == "both")
    then .package_versions.studio = $package
    else .
    end' > dist/build-manifest.json

echo "Built $BUILD_TARGET package(s) with unified version $package_version:"
if [ -n "$agent_package_version" ]; then echo "  Hermes Agent $agent_package_version"; fi
if [ -n "$studio_package_version" ]; then echo "  Hermes Studio $studio_package_version"; fi
ls -lh dist/
