#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

STUDIO_APP="$TEST_ROOT/@appcenter/HermesStudio"
STUDIO_VAR="$TEST_ROOT/studio-var"
AGENT_APP="$TEST_ROOT/@appcenter/HermesAgent"
AGENT_SHARE="$TEST_ROOT/@appshare/HermesAgent/data"
mkdir -p "$STUDIO_APP/runtime/node/bin" "$STUDIO_APP/studio/bin" "$STUDIO_APP/logs" \
  "$STUDIO_VAR" "$AGENT_APP/bin" "$AGENT_SHARE"
printf '#!/bin/sh\nexit 1\n' >"$STUDIO_APP/runtime/node/bin/node"
printf '#!/bin/sh\nexit 0\n' >"$AGENT_APP/bin/hermes-fnos"
printf '#!/bin/sh\nexit 0\n' >"$AGENT_APP/bin/hermes-python-fnos"
printf '#!/bin/sh\nexit 0\n' >"$AGENT_APP/bin/hermes-uv-fnos"
chmod 0755 "$STUDIO_APP/runtime/node/bin/node" "$AGENT_APP/bin/hermes-fnos" \
  "$AGENT_APP/bin/hermes-python-fnos" "$AGENT_APP/bin/hermes-uv-fnos"

(
  export TRIM_APPDEST="$STUDIO_APP"
  export TRIM_PKGVAR="$STUDIO_VAR"
  export TRIM_PKGTMP="$STUDIO_VAR/tmp"
  export PATH=/usr/bin:/bin
  export TRIM_PKGETC="$TEST_ROOT/no-app-config"
  unset HOME HERMES_HOME HERMES_WEB_UI_HOME NPM_CONFIG_PREFIX NPM_CONFIG_CACHE
  . "$ROOT_DIR/apps/hermes-studio/cmd/common"

  test "$HERMES_HOME" = "$AGENT_SHARE"
  test "$HOME" = "$STUDIO_VAR/web-ui/coding-agent-home"
  test "$NPM_CONFIG_PREFIX" = "$STUDIO_VAR/web-ui/coding-agent-npm"
  test "$NPM_CONFIG_CACHE" = "$STUDIO_VAR/web-ui/npm-cache"
  test -d "$HOME"
  test -d "$NPM_CONFIG_PREFIX"
  test -d "$NPM_CONFIG_CACHE"
  case ":$PATH:" in
    *":$NPM_CONFIG_PREFIX/bin:"*) ;;
    *) exit 1 ;;
  esac
)

echo 'Studio coding-agent environment checks passed.'
