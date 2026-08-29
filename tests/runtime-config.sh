#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

# fnOS App Settings must persist authorized paths, including spaces, and
# refresh the metadata consumed by Hermes Studio.
mkdir -p "$TEST_ROOT/app/cmd" "$TEST_ROOT/etc" "$TEST_ROOT/var"
cp "$ROOT_DIR/apps/hermes-agent/cmd/config_callback" "$TEST_ROOT/app/cmd/"
cp "$ROOT_DIR/apps/hermes-agent/cmd/configuration" "$TEST_ROOT/app/cmd/"
chmod 0755 "$TEST_ROOT/app/cmd/config_callback"
TRIM_APPDEST="$TEST_ROOT/app" \
TRIM_PKGETC="$TEST_ROOT/etc" \
TRIM_PKGVAR="$TEST_ROOT/var" \
TRIM_PKGHOME="$TEST_ROOT/home" \
TRIM_DATA_ACCESSIBLE_PATHS="$TEST_ROOT/Hermes Workspace" \
  "$TEST_ROOT/app/cmd/config_callback"

unset HERMES_HOME WORKSPACE_DIR HERMES_GATEWAY_PORT
source "$TEST_ROOT/etc/app.env"
test "$WORKSPACE_DIR" = "$TEST_ROOT/Hermes Workspace"
test "$HERMES_HOME" = "$TEST_ROOT/home"
test "$API_SERVER_HOST" = "127.0.0.1"
test "$API_SERVER_PORT" = "8642"
test "${#API_SERVER_KEY}" -ge 16
saved_api_server_key=$API_SERVER_KEY
unset HERMES_HOME WORKSPACE_DIR API_SERVER_KEY
source "$TEST_ROOT/app/.hermes-agent-fnos.env"
test "$WORKSPACE_DIR" = "$TEST_ROOT/Hermes Workspace"

# A callback unrelated to authorization must preserve the selected workspace.
TRIM_APPDEST="$TEST_ROOT/app" TRIM_PKGETC="$TEST_ROOT/etc" TRIM_PKGVAR="$TEST_ROOT/var" \
  "$TEST_ROOT/app/cmd/config_callback"
unset HERMES_HOME WORKSPACE_DIR HERMES_GATEWAY_PORT
source "$TEST_ROOT/etc/app.env"
test "$WORKSPACE_DIR" = "$TEST_ROOT/Hermes Workspace"
test "$API_SERVER_KEY" = "$saved_api_server_key"

# An explicitly empty authorization value clears access.
TRIM_APPDEST="$TEST_ROOT/app" TRIM_PKGETC="$TEST_ROOT/etc" TRIM_PKGVAR="$TEST_ROOT/var" \
TRIM_DATA_ACCESSIBLE_PATHS='' "$TEST_ROOT/app/cmd/config_callback"
unset HERMES_HOME WORKSPACE_DIR HERMES_GATEWAY_PORT
source "$TEST_ROOT/etc/app.env"
test -z "$WORKSPACE_DIR"
test "$API_SERVER_KEY" = "$saved_api_server_key"

# Verify the Studio release patch remains syntactically valid and suppresses
# only expected client disconnects/title-refinement warnings.
STUDIO_FIXTURE="$TEST_ROOT/studio"
mkdir -p "$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python"
cat >"$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python/bridge_pool.py" <<'PY'
import os


class SessionDbHolder:
    pass

def invoke(maybe_auto_title, session):
                        def title_callback(title: str) -> None:
                            pass

    maybe_auto_title(
                            final_response,
                            result.get("messages", []) if isinstance(result.get("messages"), list) else [],
                            failure_callback=getattr(session.agent, "_emit_auxiliary_failure", None),
    )
PY
cat >"$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python/bridge_broker.py" <<'PY'
import sys

def handle(conn):
    try:
        conn.send(b"ok")
        except Exception as exc:
            print(f"[hermes-bridge-broker] connection error: {exc}", file=sys.stderr, flush=True)
        finally:
            conn.close()
PY
python3 "$ROOT_DIR/scripts/patch-studio-runtime.py" "$STUDIO_FIXTURE"
grep -q 'def title_callback(title: str, _source: str = "")' "$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python/bridge_pool.py"
grep -q 'conversation_history=(' "$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python/bridge_pool.py"
grep -q 'failure_callback=None' "$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python/bridge_pool.py"
grep -q 'except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError)' "$STUDIO_FIXTURE/packages/server/src/services/hermes/agent-bridge/python/bridge_broker.py"

echo 'Runtime configuration checks passed.'
