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

latest_agent_release() {
  local repository=$1
  local candidates
  candidates=$(gh api "repos/$repository/releases?per_page=100" --paginate \
    --jq '
      .[] |
      select(.draft == false and .prerelease == false) |
      [(.published_at // ""), .tag_name, (.name // "")] |
      @tsv
    ')
  printf '%s\n' "$candidates" | sort -r | head -n1 | cut -f2-
}

# Studio tags may refer to Android/HStudio releases; resolve the actual Web UI asset version.
latest_studio_release() {
  local repository=$1
  local candidates
  candidates=$(gh api "repos/$repository/releases?per_page=100" --paginate \
    --jq '
      .[] |
      select(.draft == false and .prerelease == false) |
      . as $release |
      .assets[]? |
      select(.name | test("^hermes-web-ui-[0-9]+[.][0-9]+[.][0-9]+[.]tar[.]gz$")) |
      [$release.tag_name, (.name | capture("^hermes-web-ui-(?<version>[0-9]+[.][0-9]+[.][0-9]+)[.]tar[.]gz$").version)] |
      @tsv
    ')
  printf '%s\n' "$candidates" | sort -t$'\t' -k2,2V | tail -n1
}

release_commit() {
  local repository=$1
  local tag=$2
  gh api "repos/${repository}/commits/${tag}" --jq '.sha'
}

: > "${ROOT_DIR}/build/upstream.env"
if [ "$target" = agent ] || [ "$target" = both ]; then
  agent_release=$(latest_agent_release NousResearch/hermes-agent)
  test -n "$agent_release"
  agent_tag=$(printf '%s\n' "$agent_release" | cut -f1)
  agent_name=$(printf '%s\n' "$agent_release" | cut -f2-)
  test -n "$agent_tag" -a -n "$agent_name"
  agent_display_version=$(printf '%s\n' "$agent_name" | sed -nE 's/^.*(v[0-9]+[.][0-9]+[.][0-9]+ \(v[^)]+\)).*$/\1/p')
  test -n "$agent_display_version"
  agent_version=$(printf '%s\n' "$agent_display_version" | sed -E 's/^v([0-9]+[.][0-9]+[.][0-9]+).*/\1/')
  agent_commit=$(release_commit NousResearch/hermes-agent "$agent_tag")
  test -n "$agent_commit"
  {
    printf 'HERMES_AGENT_TAG=%s\n' "$agent_tag"
    printf 'HERMES_AGENT_VERSION=%s\n' "$agent_version"
    printf 'HERMES_AGENT_DISPLAY_VERSION=%q\n' "$agent_display_version"
    printf 'HERMES_AGENT_COMMIT=%s\n' "$agent_commit"
  } >> "${ROOT_DIR}/build/upstream.env"
fi

if [ "$target" = studio ] || [ "$target" = both ]; then
  studio_release=$(latest_studio_release EKKOLearnAI/hermes-studio)
  test -n "$studio_release"
  studio_tag=$(printf '%s\n' "$studio_release" | cut -f1)
  studio_version=$(printf '%s\n' "$studio_release" | cut -f2)
  test -n "$studio_tag" -a -n "$studio_version"
  studio_commit=$(release_commit EKKOLearnAI/hermes-studio "$studio_tag")
  test -n "$studio_commit"
  {
    printf 'HERMES_STUDIO_TAG=%s\n' "$studio_tag"
    printf 'HERMES_STUDIO_VERSION=%s\n' "$studio_version"
    printf 'HERMES_STUDIO_DISPLAY_VERSION=%q\n' "v$studio_version"
    printf 'HERMES_STUDIO_COMMIT=%s\n' "$studio_commit"
  } >> "${ROOT_DIR}/build/upstream.env"
fi

echo "Resolved formal Release(s) for $target:"
cat "${ROOT_DIR}/build/upstream.env"
