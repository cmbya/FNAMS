#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r file; do
  bash -n "$file"
done < <(find "$ROOT_DIR/apps" "$ROOT_DIR/scripts" -type f \( -name '*.sh' -o -path '*/cmd/*' \))

jq empty "$ROOT_DIR/apps/hermes-agent/config/privilege"
jq empty "$ROOT_DIR/apps/hermes-agent/config/resource"
jq empty "$ROOT_DIR/apps/hermes-studio/config/privilege"
jq empty "$ROOT_DIR/apps/hermes-studio/config/resource"
jq empty "$ROOT_DIR/apps/hermes-agent/app/ui/config"
jq empty "$ROOT_DIR/apps/hermes-studio/app/ui/config"

grep -q '^appname=HermesAgent$' "$ROOT_DIR/apps/hermes-agent/manifest"
grep -q '^appname=HermesStudio$' "$ROOT_DIR/apps/hermes-studio/manifest"
grep -q '^install_dep_apps=HermesAgent>0.1.0$' "$ROOT_DIR/apps/hermes-studio/manifest"
grep -q '^      package_version:$' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q 'PACKAGE_VERSION_INPUT' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q 'PACKAGE_VERSION=' "$ROOT_DIR/scripts/build-release.sh"
grep -q 'next-package-version.sh' "$ROOT_DIR/scripts/build-release.sh"
grep -q 'BUILD_TARGET=\${BUILD_TARGET:-agent}' "$ROOT_DIR/scripts/build-release.sh"
grep -q 'AGENT_PACKAGE_VERSION' "$ROOT_DIR/scripts/build-agent-fpk.sh"
grep -q 'STUDIO_PACKAGE_VERSION' "$ROOT_DIR/scripts/build-studio-fpk.sh"
grep -q 'HermesAgent-' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q 'HermesStudio-' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q 'display_version' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q 'Hermes Agent + Studio fnOS' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q 'gh release edit "$release_tag" --title "$release_title" --notes "$release_notes"' "$ROOT_DIR/.github/workflows/build-release.yml"
grep -q '10 2 \* \* \*' "$ROOT_DIR/.github/workflows/check-upstream-release.yml"
grep -q 'target=both' "$ROOT_DIR/.github/workflows/check-upstream-release.yml"
grep -q 'latest_studio_web_tag' "$ROOT_DIR/.github/workflows/check-upstream-release.yml"
grep -q 'agent_built' "$ROOT_DIR/scripts/build-release.sh"
grep -q 'unified_release_tags' "$ROOT_DIR/.github/workflows/check-upstream-release.yml"
grep -q 'last_successful_upstream' "$ROOT_DIR/.github/workflows/check-upstream-release.yml"
grep -q 'gh release download' "$ROOT_DIR/.github/workflows/check-upstream-release.yml"
(
  source "$ROOT_DIR/versions.lock"
  [[ "$PACKAGE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
  test "$HERMES_AGENT_DISPLAY_VERSION" = "v0.21.1 (v2026.9.7)"
)
test -f "$ROOT_DIR/scripts/next-package-version.sh"
test -f "$ROOT_DIR/scripts/update-versions-lock.sh"
test -x "$ROOT_DIR/scripts/package-fpk.sh"
test -f "$ROOT_DIR/scripts/render-svg-icon.sh"
test -x "$ROOT_DIR/scripts/compact-agent-runtime.sh"
test -x "$ROOT_DIR/apps/hermes-agent/cmd/ensure_runtime"

grep -q '^export HERMES_INTERACTIVE=1$' "$ROOT_DIR/apps/hermes-studio/cmd/common"
grep -q 'bridge.ready === true' "$ROOT_DIR/apps/hermes-studio/cmd/main"
grep -q '"url": "/status"' "$ROOT_DIR/apps/hermes-agent/app/ui/config"
grep -q 'agent-browser@${AGENT_BROWSER_VERSION}' "$ROOT_DIR/scripts/bundle-agent-runtime.sh"
grep -q 'HERMES_BUNDLED_SKILLS' "$ROOT_DIR/scripts/bundle-agent-runtime.sh"
grep -q 'sync_bundled_skills' "$ROOT_DIR/apps/hermes-agent/cmd/main"
grep -q 'official hermes-agent skill' "$ROOT_DIR/scripts/verify-fpk-payload.sh"
grep -q 'HERMES_GATEWAY_LOCK_DIR' "$ROOT_DIR/apps/hermes-agent/cmd/common"
grep -q 'XDG_STATE_HOME' "$ROOT_DIR/apps/hermes-agent/cmd/common"
grep -q 'TERMINAL_CWD' "$ROOT_DIR/apps/hermes-agent/cmd/common"
grep -q '^export HOME HERMES_HOME WORKSPACE_DIR$' "$ROOT_DIR/apps/hermes-agent/cmd/common"
grep -q -- '--no-same-owner' "$ROOT_DIR/scripts/fetch-upstream.sh"
grep -q 'ensure_api_server_key' "$ROOT_DIR/apps/hermes-agent/cmd/configuration"
grep -q "printf 'HOME='" "$ROOT_DIR/apps/hermes-agent/cmd/configuration"
grep -q 'API_SERVER_KEY=' "$ROOT_DIR/apps/hermes-agent/cmd/configuration"
grep -q 'export API_SERVER_HOST API_SERVER_PORT' "$ROOT_DIR/apps/hermes-agent/cmd/common"
grep -q 'export API_SERVER_KEY' "$ROOT_DIR/apps/hermes-agent/cmd/common"
grep -q 'gateway health diagnosis' "$ROOT_DIR/apps/hermes-agent/cmd/main"

if command -v node >/dev/null 2>&1; then
  node --check "$ROOT_DIR/apps/hermes-studio/app/logs/log_server.mjs"
fi
python3 -c 'from pathlib import Path; p=Path("'"$ROOT_DIR"'/apps/hermes-agent/app/logs/log_server.py"); compile(p.read_text(), str(p), "exec")'
python3 -m py_compile "$ROOT_DIR/scripts/patch-studio-runtime.py"

stub_bin=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' > "$stub_bin/gh"
chmod 0755 "$stub_bin/gh"
test "$(PATH="$stub_bin:$PATH" GITHUB_REPOSITORY=invalid/invalid bash "$ROOT_DIR/scripts/next-package-version.sh" 0.1.0)" = "0.1.1"
test "$(PATH="$stub_bin:$PATH" GITHUB_REPOSITORY=invalid/invalid bash "$ROOT_DIR/scripts/next-package-version.sh" 0.1.9)" = "0.2.0"
test "$(PATH="$stub_bin:$PATH" GITHUB_REPOSITORY=invalid/invalid bash "$ROOT_DIR/scripts/next-package-version.sh" 1.2.8)" = "1.2.9"

bash "$ROOT_DIR/tests/runtime-config.sh"
echo 'Static source checks passed.'
