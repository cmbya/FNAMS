#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK_LOG=${ROOT_DIR}/dist/fpk-payload-check.log
mkdir -p "${ROOT_DIR}/dist"
: >"${CHECK_LOG}"

for fpk in "${ROOT_DIR}"/dist/*.fpk; do
  test -s "$fpk"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  printf 'checking %s\n' "$(basename "$fpk")" | tee -a "$CHECK_LOG"
  tar -xf "$fpk" -C "$tmp" --no-same-owner
  app_tgz=$(find "$tmp" -type f -name app.tgz -print -quit)
  test -n "$app_tgz" || { echo "app.tgz not found in $fpk" | tee -a "$CHECK_LOG" >&2; exit 1; }
  gzip -t "$app_tgz"
  tar -tzf "$app_tgz" >/dev/null
  if tar -tzf "$app_tgz" | awk '/(^|\/)\.\.($|\/)|^\// {bad=1; print; exit} END {exit bad}'; then
    :
  else
    echo "unsafe path found in $(basename "$fpk")" | tee -a "$CHECK_LOG" >&2
    exit 1
  fi
  printf '  app.tgz OK: %s bytes\n' "$(stat -c '%s' "$app_tgz")" | tee -a "$CHECK_LOG"
done

echo 'FPK payload validation passed.' | tee -a "$CHECK_LOG"
