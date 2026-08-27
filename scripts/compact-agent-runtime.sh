#!/usr/bin/env bash
set -euo pipefail

# fnOS may reject an app.tgz containing tens of thousands of Python and
# Chromium files. Keep the fnOS-facing app.tgz deliberately small, while
# still shipping every runtime dependency inside the FPK. install_callback
# expands this one bundled payload locally with the included static BusyBox.

APP_DIR=${1:?agent app directory is required}
PACKAGE_VERSION=${2:?package version is required}
BUSYBOX_BIN=${BUSYBOX_BIN:-$(command -v busybox || true)}

test -d "$APP_DIR/bin"
test -d "$APP_DIR/runtime"
test -n "$BUSYBOX_BIN"
test -x "$BUSYBOX_BIN"

install -d "$APP_DIR/tools"
install -m 0755 "$BUSYBOX_BIN" "$APP_DIR/tools/busybox"
printf '%s\n' "$PACKAGE_VERSION" > "$APP_DIR/runtime/.fnos-runtime-version"

rm -f "$APP_DIR/runtime-payload.tgz"
tar --format=gnu --sort=name --mtime='UTC 1970-01-01' \
  --owner=0 --group=0 --numeric-owner \
  -czf "$APP_DIR/runtime-payload.tgz" -C "$APP_DIR" bin runtime

test -s "$APP_DIR/runtime-payload.tgz"
gzip -t "$APP_DIR/runtime-payload.tgz"
"$APP_DIR/tools/busybox" tar -tzf "$APP_DIR/runtime-payload.tgz" >/dev/null

rm -rf "$APP_DIR/bin" "$APP_DIR/runtime"
printf 'Prepared compact Agent runtime payload: %s bytes\n' \
  "$(stat -c '%s' "$APP_DIR/runtime-payload.tgz")"
