#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

target=${1:?target is required: agent, studio, or both}
manifest=${2:-dist/build-manifest.json}
case "$target" in
  agent|studio|both) ;;
  *) echo "target must be agent, studio, or both (got: $target)" >&2; exit 2 ;;
esac

test -f "$manifest"
source versions.lock
if [ -f build/upstream.env ]; then
  source build/upstream.env
fi

agent_package_version=$(jq -r '.package_versions.agent // empty' "$manifest")
studio_package_version=$(jq -r '.package_versions.studio // empty' "$manifest")
test "$target" = studio || test -n "$agent_package_version"
test "$target" = agent || test -n "$studio_package_version"

set_lock_value() {
  local key=$1
  local value=$2
  if grep -q "^$key=" versions.lock; then
    sed -E -i "s/^$key=.*/$key=$value/" versions.lock
  else
    printf '%s=%s\n' "$key" "$value" >> versions.lock
  fi
}

update_agent=0
update_studio=0
if [ "$target" = agent ] || [ "$target" = both ]; then
  set_lock_value AGENT_PACKAGE_VERSION "$agent_package_version"
  update_agent=1
  if [ -n "${HERMES_AGENT_TAG:-}" ]; then
    set_lock_value HERMES_AGENT_TAG "$HERMES_AGENT_TAG"
    set_lock_value HERMES_AGENT_VERSION "${HERMES_AGENT_VERSION:-${HERMES_AGENT_TAG#v}}"
    if [ -n "${HERMES_AGENT_COMMIT:-}" ]; then
      set_lock_value HERMES_AGENT_COMMIT "$HERMES_AGENT_COMMIT"
    fi
  fi
fi
if [ "$target" = studio ] || [ "$target" = both ]; then
  set_lock_value STUDIO_PACKAGE_VERSION "$studio_package_version"
  update_studio=1
  if [ -n "${HERMES_STUDIO_TAG:-}" ]; then
    set_lock_value HERMES_STUDIO_TAG "$HERMES_STUDIO_TAG"
    set_lock_value HERMES_STUDIO_VERSION "${HERMES_STUDIO_VERSION:-${HERMES_STUDIO_TAG#v}}"
    if [ -n "${HERMES_STUDIO_COMMIT:-}" ]; then
      set_lock_value HERMES_STUDIO_COMMIT "$HERMES_STUDIO_COMMIT"
    fi
  fi
fi

git add versions.lock
if git diff --cached --quiet; then
  echo "No version lock changes."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
if [ "$update_agent" = 1 ] && [ "$update_studio" = 1 ]; then
  message="chore(release): record Agent and Studio versions"
else
  message="chore(release): record ${target} version"
fi
git commit -m "$message"
git push origin HEAD:main
