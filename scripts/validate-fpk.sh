#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
for file in "$ROOT_DIR"/apps/*/manifest "$ROOT_DIR"/apps/*/config/*; do
  test -f "$file"
  case "$(basename "$file")" in privilege|resource) jq empty "$file";; esac
done
while IFS= read -r file; do bash -n "$file"; done < <(find "$ROOT_DIR/apps" "$ROOT_DIR/scripts" -type f -perm -u+x -print)
for fpk in "$ROOT_DIR"/dist/*.fpk; do
  test -s "$fpk"
  tar -tf "$fpk" >/dev/null
done
"$ROOT_DIR/scripts/verify-fpk-payload.sh"
echo 'Static FPK validation passed.'
