#!/usr/bin/env bash
set -euo pipefail

# Build the fnOS two-layer archive in a clean staging directory.
# The outer .fpk contains app.tgz; app.tgz is extracted to TRIM_APPDEST/target.

STAGE=${1:?staging directory is required}
OUTPUT=${2:?output FPK path is required}

export COPYFILE_DISABLE=1
export LC_ALL=C
export TZ=UTC

test -d "$STAGE/app"
test -f "$STAGE/manifest"
test -d "$STAGE/cmd"
test -d "$STAGE/config"
test -d "$STAGE/wizard"
test -f "$STAGE/ICON.PNG"
test -f "$STAGE/ICON_256.PNG"

rm -f "$STAGE/app.tgz" "$OUTPUT"

# GNU tar + gzip -n produces the same simple relative-path archive shape used
# by the fnOS native-app examples. Do not archive the app directory itself.
tar --format=gnu --sort=name --mtime='UTC 1970-01-01' \
  --owner=0 --group=0 --numeric-owner \
  -czf "$STAGE/app.tgz" -C "$STAGE/app" .

test -s "$STAGE/app.tgz"
gzip -t "$STAGE/app.tgz"

checksum=$(md5sum "$STAGE/app.tgz" | awk '{print $1}')
if grep -qE '^[[:space:]]*checksum[[:space:]]*=' "$STAGE/manifest"; then
  sed -E -i "s/^[[:space:]]*checksum[[:space:]]*=.*/checksum = ${checksum}/" "$STAGE/manifest"
else
  printf '\nchecksum = %s\n' "$checksum" >> "$STAGE/manifest"
fi
grep -qE "^[[:space:]]*checksum[[:space:]]*=[[:space:]]*${checksum}[[:space:]]*$" "$STAGE/manifest"

# app is now represented by app.tgz and must not be copied into the outer FPK.
rm -rf "$STAGE/app"

tar --format=gnu --sort=name --mtime='UTC 1970-01-01' \
  --owner=0 --group=0 --numeric-owner \
  -czf "$OUTPUT.tmp" -C "$STAGE" \
  app.tgz manifest ICON.PNG ICON_256.PNG cmd config wizard
mv "$OUTPUT.tmp" "$OUTPUT"

test -s "$OUTPUT"
printf 'Built %s (%s bytes), app.tgz MD5 %s\n' \
  "$OUTPUT" "$(stat -c '%s' "$OUTPUT")" "$checksum"
