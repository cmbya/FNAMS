#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK_LOG=${ROOT_DIR}/dist/fpk-payload-check.log
mkdir -p "${ROOT_DIR}/dist"
: >"${CHECK_LOG}"

for fpk in "${ROOT_DIR}"/dist/*.fpk; do
  test -s "$fpk"
  tmp=$(mktemp -d)
  printf 'checking %s\n' "$(basename "$fpk")" | tee -a "$CHECK_LOG"
  outer_listing=$(tar -tzf "$fpk")
  printf '  outer members:\n%s\n' "$outer_listing" | sed -n '1,20p' | tee -a "$CHECK_LOG" >/dev/null
  for required in manifest app.tgz cmd/main config/privilege config/resource wizard/install ICON.PNG ICON_256.PNG; do
    printf '%s\n' "$outer_listing" | grep -qx "$required" || {
      echo "missing outer member $required in $(basename "$fpk")" | tee -a "$CHECK_LOG" >&2
      exit 1
    }
  done
  if printf '%s\n' "$outer_listing" | grep -qE '(^|/)app(/|$)'; then
    echo "outer FPK must contain app.tgz, not an app directory" | tee -a "$CHECK_LOG" >&2
    exit 1
  fi
  tar -xzf "$fpk" -C "$tmp" --no-same-owner
  app_tgz=$(find "$tmp" -type f -name app.tgz -print -quit)
  test -n "$app_tgz" || { echo "app.tgz not found in $fpk" | tee -a "$CHECK_LOG" >&2; exit 1; }
  gzip -t "$app_tgz"
  app_listing=$(tar -tzf "$app_tgz")
  if printf '%s\n' "$app_listing" | awk '/(^|\/)\.\.($|\/)|^\// {bad=1; print; exit} END {exit bad}'; then
    :
  else
    echo "unsafe path found in $(basename "$fpk")" | tee -a "$CHECK_LOG" >&2
    exit 1
  fi
  duplicate=$(printf '%s\n' "$app_listing" | sort | uniq -d | head -n 1 || true)
  test -z "$duplicate" || { echo "duplicate app.tgz member: $duplicate" | tee -a "$CHECK_LOG" >&2; exit 1; }
  checksum=$(awk -F= '$1 ~ /^[[:space:]]*checksum[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$tmp/manifest")
  actual_checksum=$(md5sum "$app_tgz" | awk '{print $1}')
  test -n "$checksum" || { echo "manifest checksum is missing" | tee -a "$CHECK_LOG" >&2; exit 1; }
  test "$checksum" = "$actual_checksum" || {
    echo "manifest checksum mismatch: expected $checksum actual $actual_checksum" | tee -a "$CHECK_LOG" >&2
    exit 1
  }
  if command -v busybox >/dev/null 2>&1; then
    busybox tar -tzf "$app_tgz" >/dev/null
  fi
  printf '  app.tgz OK: %s bytes, md5 %s, members %s\n' \
    "$(stat -c '%s' "$app_tgz")" "$actual_checksum" "$(printf '%s\n' "$app_listing" | wc -l)" | tee -a "$CHECK_LOG"

  appname=$(awk -F= '$1 == "appname" {print $2; exit}' "$tmp/manifest")
  if [ "$appname" = "HermesAgent" ]; then
    printf '%s\n' "$app_listing" | grep -qx './runtime-payload.tgz' || {
      echo "Agent bootstrap app.tgz is missing runtime-payload.tgz" | tee -a "$CHECK_LOG" >&2
      exit 1
    }
    test -x "$tmp/tools/busybox" || {
      echo "Agent bootstrap app.tgz is missing executable tools/busybox" | tee -a "$CHECK_LOG" >&2
      exit 1
    }
    payload="$tmp/runtime-payload.tgz"
    gzip -t "$payload"
    runtime_listing=$(tar -tzf "$payload")
    if printf '%s\n' "$runtime_listing" | awk '/(^|\/)\.\.($|\/)|^\// {bad=1; print; exit} END {exit bad}'; then
      :
    else
      echo "unsafe runtime payload path found in $(basename "$fpk")" | tee -a "$CHECK_LOG" >&2
      exit 1
    fi
    unpacked="$tmp/unpacked-runtime"
    mkdir -p "$unpacked"
    "$tmp/tools/busybox" tar -xzf "$payload" -C "$unpacked"
    test -x "$unpacked/runtime/python/bin/python3" || {
      echo "Agent runtime payload did not extract Python" | tee -a "$CHECK_LOG" >&2
      exit 1
    }
    test -x "$unpacked/bin/hermes-fnos" || {
      echo "Agent runtime payload did not extract launcher" | tee -a "$CHECK_LOG" >&2
      exit 1
    }
    test -f "$unpacked/runtime/.fnos-runtime-version" || {
      echo "Agent runtime payload version marker is missing" | tee -a "$CHECK_LOG" >&2
      exit 1
    }
    printf '  Agent runtime payload OK: %s bytes, members %s, version %s\n' \
      "$(stat -c '%s' "$payload")" "$(printf '%s\n' "$runtime_listing" | wc -l)" \
      "$(tr -d '\n' < "$unpacked/runtime/.fnos-runtime-version")" | tee -a "$CHECK_LOG"
  fi
  rm -rf "$tmp"
done

echo 'FPK payload validation passed.' | tee -a "$CHECK_LOG"
