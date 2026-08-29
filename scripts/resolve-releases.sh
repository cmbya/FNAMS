#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "${ROOT_DIR}/build"
command -v gh >/dev/null 2>&1 || { echo 'gh is required.' >&2; exit 1; }

target=${1:-${BUILD_TARGET:-both}}
case "$target" in
  agent|studio|both) ;;
  *) echo "BUILD_TARGET must be agent, studio, or both (got: $target)" >&2; exit 2 ;;
esac

latest_tag() {
  local repository=$1
  local candidates
  candidates=$(gh api "repos/${repository}/releases?per_page=100" --paginate \
    --jq '([.[] | select(.draft == false and .prerelease == false)] | .[0].tag_name) // empty')
  printf '%s\n' "${candidates%%$'\n'*}"
}

release_commit() {
  local repository=$1
  local tag=$2
  gh api "repos/${repository}/commits/${tag}" --jq '.sha'
}

: > "${ROOT_DIR}/build/upstream.env"
if [ "$target" = agent ] || [ "$target" = both ]; then
  agent_tag=$(latest_tag NousResearch/hermes-agent)
  test -n "$agent_tag"
  agent_commit=$(release_commit NousResearch/hermes-agent "$agent_tag")
  test -n "$agent_commit"
  {
    printf 'HERMES_AGENT_TAG=%s\n' "$agent_tag"
    printf 'HERMES_AGENT_VERSION=%s\n' "${agent_tag#v}"
    printf 'HERMES_AGENT_COMMIT=%s\n' "$agent_commit"
  } >> "${ROOT_DIR}/build/upstream.env"
fi

if [ "$target" = studio ] || [ "$target" = both ]; then
  studio_tag=$(latest_tag EKKOLearnAI/hermes-studio)
  test -n "$studio_tag"
  studio_commit=$(release_commit EKKOLearnAI/hermes-studio "$studio_tag")
  test -n "$studio_commit"
  {
    printf 'HERMES_STUDIO_TAG=%s\n' "$studio_tag"
    printf 'HERMES_STUDIO_VERSION=%s\n' "${studio_tag#v}"
    printf 'HERMES_STUDIO_COMMIT=%s\n' "$studio_commit"
  } >> "${ROOT_DIR}/build/upstream.env"
fi

echo "Resolved formal Release(s) for $target:"
cat "${ROOT_DIR}/build/upstream.env"
