#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NODE="${ROOT_DIR}/fpk/app/runtime/node/bin/node"
PYTHON="${ROOT_DIR}/fpk/app/runtime/python/bin/python3"
CHROMIUM="${ROOT_DIR}/fpk/app/runtime/chromium/chromium"

test -x "${NODE}"
test -x "${PYTHON}"
test -x "${CHROMIUM}"
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) echo 'Build host must be x86_64.' >&2; exit 1 ;;
esac
"${NODE}" --version
"${PYTHON}" --version
printf '%s\n' "Runtime verification passed for x86_64."
