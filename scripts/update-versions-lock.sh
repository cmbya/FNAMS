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

package_version=$(jq -r '.package_version // empty' "$manifest")
test -n "$package_version"

agent_upstream_version=$(jq -r '.upstream.agent.version // .hermes_agent.version // empty' "$manifest")
agent_upstream_display=$(jq -r '.upstream.agent.display_version // .hermes_agent.display_version // empty' "$manifest")
agent_upstream_tag=$(jq -r '.upstream.agent.tag // .hermes_agent.tag // empty' "$manifest")
studio_upstream_version=$(jq -r '.upstream.studio.version // .hermes_studio.version // empty' "$manifest")
studio_upstream_display=$(jq -r '.upstream.studio.display_version // .hermes_studio.display_version // empty' "$manifest")
studio_upstream_tag=$(jq -r '.upstream.studio.tag // .hermes_studio.tag // empty' "$manifest")

set_lock_value() {
  local key=$1
  local value=$2
  local quoted_value
  printf -v quoted_value "'%s'" "$value"
  if grep -q "^$key=" versions.lock; then
    sed -E -i "s|^$key=.*|$key=$quoted_value|" versions.lock
  else
    printf '%s=%s\n' "$key" "$quoted_value" >> versions.lock
  fi
}

set_lock_value PACKAGE_VERSION "$package_version"

update_agent=0
update_studio=0
if [ "$target" = agent ] || [ "$target" = both ]; then
  test -n "$agent_upstream_version" -a -n "$agent_upstream_display" -a -n "$agent_upstream_tag"
  set_lock_value HERMES_AGENT_VERSION "$agent_upstream_version"
  set_lock_value HERMES_AGENT_DISPLAY_VERSION "$agent_upstream_display"
  set_lock_value HERMES_AGENT_TAG "$agent_upstream_tag"
  if [ -n "${HERMES_AGENT_COMMIT:-}" ]; then
    set_lock_value HERMES_AGENT_COMMIT "$HERMES_AGENT_COMMIT"
  fi
  update_agent=1
fi
if [ "$target" = studio ] || [ "$target" = both ]; then
  test -n "$studio_upstream_version" -a -n "$studio_upstream_display" -a -n "$studio_upstream_tag"
  set_lock_value HERMES_STUDIO_VERSION "$studio_upstream_version"
  set_lock_value HERMES_STUDIO_DISPLAY_VERSION "$studio_upstream_display"
  set_lock_value HERMES_STUDIO_TAG "$studio_upstream_tag"
  if [ -n "${HERMES_STUDIO_COMMIT:-}" ]; then
    set_lock_value HERMES_STUDIO_COMMIT "$HERMES_STUDIO_COMMIT"
  fi
  update_studio=1
fi

git add versions.lock
if git diff --cached --quiet; then
  echo "No version lock changes."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
if [ "$update_agent" = 1 ] && [ "$update_studio" = 1 ]; then
  message="chore(release): record unified Agent and Studio versions"
else
  message="chore(release): record unified ${target} version"
fi
git commit -m "$message"
git push origin HEAD:main
