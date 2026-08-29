#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
while IFS= read -r file; do bash -n "$file"; done < <(find "$ROOT_DIR/apps" "$ROOT_DIR/scripts" -type f \( -name '*.sh' -o -path '*/cmd/*' \))
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
grep -q 'PACKAGE_VERSION=\${PACKAGE_VERSION:-\$FPK_VERSION}' "$ROOT_DIR/scripts/build-release.sh"
grep -q 'version=\${FPK_VERSION}' "$ROOT_DIR/scripts/build-agent-fpk.sh"
grep -q 'version=\${FPK_VERSION}' "$ROOT_DIR/scripts/build-studio-fpk.sh"
test -x "$ROOT_DIR/scripts/package-fpk.sh"
test -f "$ROOT_DIR/scripts/render-svg-icon.sh"
test -x "$ROOT_DIR/scripts/compact-agent-runtime.sh"
test -x "$ROOT_DIR/apps/hermes-agent/cmd/ensure_runtime"
grep -q '^export HERMES_INTERACTIVE=1$' "$ROOT_DIR/apps/hermes-studio/cmd/common"
grep -q 'bridge.ready === true' "$ROOT_DIR/apps/hermes-studio/cmd/main"
grep -q '"url": "/status"' "$ROOT_DIR/apps/hermes-agent/app/ui/config"
grep -q 'agent-browser@${AGENT_BROWSER_VERSION}' "$ROOT_DIR/scripts/bundle-agent-runtime.sh"
grep -q -- '--no-same-owner' "$ROOT_DIR/scripts/fetch-upstream.sh"
grep -q 'ensure_api_server_key' "$ROOT_DIR/apps/hermes-agent/cmd/configuration"
grep -q 'API_SERVER_KEY=' "$ROOT_DIR/apps/hermes-agent/cmd/configuration"
grep -q 'gateway health diagnosis' "$ROOT_DIR/apps/hermes-agent/cmd/main"
if command -v node >/dev/null 2>&1; then
  node --check "$ROOT_DIR/apps/hermes-studio/app/logs/log_server.mjs"
fi
python3 -c 'from pathlib import Path; p=Path("'"$ROOT_DIR"'/apps/hermes-agent/app/logs/log_server.py"); compile(p.read_text(), str(p), "exec")'
python3 -m py_compile "$ROOT_DIR/scripts/patch-studio-runtime.py"
bash "$ROOT_DIR/tests/runtime-config.sh"
echo 'Static source checks passed.'
