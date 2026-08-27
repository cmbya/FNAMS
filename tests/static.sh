#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
while IFS= read -r file; do bash -n "$file"; done < <(find "$ROOT_DIR/apps" "$ROOT_DIR/scripts" -type f \( -name '*.sh' -o -path '*/cmd/*' \))
jq empty "$ROOT_DIR/apps/hermes-agent/config/privilege"
jq empty "$ROOT_DIR/apps/hermes-agent/config/resource"
jq empty "$ROOT_DIR/apps/hermes-studio/config/privilege"
jq empty "$ROOT_DIR/apps/hermes-studio/config/resource"
grep -q '^appname=HermesAgent$' "$ROOT_DIR/apps/hermes-agent/manifest"
grep -q '^appname=HermesStudio$' "$ROOT_DIR/apps/hermes-studio/manifest"
grep -q '^install_dep_apps=HermesAgent>0.1.0$' "$ROOT_DIR/apps/hermes-studio/manifest"
test -x "$ROOT_DIR/scripts/package-fpk.sh"
if command -v node >/dev/null 2>&1; then
  node --check "$ROOT_DIR/apps/hermes-studio/app/logs/log_server.mjs"
fi
python3 -c 'from pathlib import Path; p=Path("'"$ROOT_DIR"'/apps/hermes-agent/app/logs/log_server.py"); compile(p.read_text(), str(p), "exec")'
echo 'Static source checks passed.'
