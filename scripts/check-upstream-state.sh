#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

target=${1:-both}
case "$target" in
  agent|studio|both) ;;
  *) echo "target must be agent, studio, or both (got: $target)" >&2; exit 2 ;;
esac

source versions.lock
repository=${GITHUB_REPOSITORY:-cmbya/FNAMS}

latest_formal_tag() {
  local upstream_repository=$1
  local candidates
  candidates=$(gh api "repos/$upstream_repository/releases?per_page=100" --paginate \
    --jq '
      .[] |
      select(.draft == false and .prerelease == false) |
      [(.published_at // ""), .tag_name] |
      @tsv
    ')
  printf '%s\n' "$candidates" | sort -r | head -n1 | cut -f2
}

latest_studio_web_tag() {
  local upstream_repository=$1
  local candidates
  candidates=$(gh api "repos/$upstream_repository/releases?per_page=100" --paginate \
    --jq '
      .[] |
      select(.draft == false and .prerelease == false) |
      . as $release |
      .assets[]? |
      select(.name | test("^hermes-web-ui-[0-9]+[.][0-9]+[.][0-9]+[.]tar[.]gz$")) |
      [$release.tag_name, (.name | capture("^hermes-web-ui-(?<version>[0-9]+[.][0-9]+[.][0-9]+)[.]tar[.]gz$").version)] |
      @tsv
    ')
  printf '%s\n' "$candidates" | sort -t$'\t' -k2,2V | tail -n1 | cut -f1
}

unified_release_tags() {
  gh api "repos/$repository/releases?per_page=100" --paginate \
    --jq '
      .[] |
      select(.draft == false and .prerelease == false) |
      select(.tag_name | test("^v[0-9]+[.][0-9]+[.][0-9]+$")) |
      select((([.assets[]?.name] | index("build-manifest.json"))) != null) |
      .tag_name
    ' |
    sort -V -r
}

has_asset() {
  local asset_names=$1
  local wanted=$2
  printf '%s\n' "$asset_names" | grep -Fx -- "$wanted" >/dev/null
}

last_successful_upstream() {
  local state_dir=$1
  local compiled_agent=
  local compiled_studio=

  while IFS= read -r release_tag; do
    [ -n "$release_tag" ] || continue

    manifest_dir="$state_dir/$release_tag"
    mkdir -p "$manifest_dir"
    if ! gh release download "$release_tag" \
      --repo "$repository" \
      --pattern build-manifest.json \
      --dir "$manifest_dir" \
      --clobber >/dev/null 2>&1; then
      continue
    fi

    manifest="$manifest_dir/build-manifest.json"
    [ -s "$manifest" ] || continue

    if ! manifest_target=$(jq -r '.build_target // empty' "$manifest" 2>/dev/null); then
      continue
    fi
    case "$manifest_target" in
      agent|studio|both) ;;
      *) continue ;;
    esac

    package_version=$(jq -r '.package_version // empty' "$manifest")
    if [[ ! "$package_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ "v$package_version" != "$release_tag" ]; then
      continue
    fi
    if ! jq -e '(.upstream | type == "object")' "$manifest" >/dev/null 2>&1; then
      continue
    fi

    release_asset_names=$(gh release view "$release_tag" --repo "$repository" --json assets --jq '.assets[]?.name' 2>/dev/null) || continue
    has_asset "$release_asset_names" "build-manifest.json" || continue
    has_asset "$release_asset_names" "SHA256SUMS" || continue

    agent_was_built=$(jq -r '
      if .upstream.agent.built == true
         or .build_target == "agent"
         or .build_target == "both"
      then "1" else "0" end
    ' "$manifest")
    studio_was_built=$(jq -r '
      if .upstream.studio.built == true
         or .build_target == "studio"
         or .build_target == "both"
      then "1" else "0" end
    ' "$manifest")

    agent_tag=$(jq -r '.upstream.agent.tag // .hermes_agent.tag // empty' "$manifest")
    studio_tag=$(jq -r '.upstream.studio.tag // .hermes_studio.tag // empty' "$manifest")

    if [ "$agent_was_built" = 1 ]; then
      has_asset "$release_asset_names" "HermesAgent-$package_version-fnOS-x86_64.fpk" || agent_was_built=0
    fi
    if [ "$studio_was_built" = 1 ]; then
      has_asset "$release_asset_names" "HermesStudio-$package_version-fnOS-x86_64.fpk" || studio_was_built=0
    fi

    if [ "$agent_was_built" = 1 ] && [ -n "$agent_tag" ] && [ -z "$compiled_agent" ]; then
      compiled_agent="$agent_tag"
    fi
    if [ "$studio_was_built" = 1 ] && [ -n "$studio_tag" ] && [ -z "$compiled_studio" ]; then
      compiled_studio="$studio_tag"
    fi

    if [ -n "$compiled_agent" ] && [ -n "$compiled_studio" ]; then
      break
    fi
  done <<EOF
$(unified_release_tags)
EOF

  printf '%s\t%s\n' "$compiled_agent" "$compiled_studio"
}

state_dir=$(mktemp -d)
trap 'rm -rf "$state_dir"' EXIT

recorded_state=$(last_successful_upstream "$state_dir")
IFS=$'\t' read -r compiled_agent compiled_studio <<< "$recorded_state"

# During migration, a component without a valid unified Release manifest uses
# its last recorded versions.lock tag as a temporary baseline.
if [ -z "$compiled_agent" ]; then
  compiled_agent="$HERMES_AGENT_TAG"
fi
if [ -z "$compiled_studio" ]; then
  compiled_studio="$HERMES_STUDIO_TAG"
fi

latest_agent=
latest_studio=
if [ "$target" = agent ] || [ "$target" = both ]; then
  latest_agent=$(latest_formal_tag NousResearch/hermes-agent)
  test -n "$latest_agent"
fi
if [ "$target" = studio ] || [ "$target" = both ]; then
  latest_studio=$(latest_studio_web_tag EKKOLearnAI/hermes-studio)
  test -n "$latest_studio"
fi

agent_changed=0
studio_changed=0
if [ "$target" = agent ] || [ "$target" = both ]; then
  if [ "$latest_agent" != "$compiled_agent" ]; then
    agent_changed=1
  fi
fi
if [ "$target" = studio ] || [ "$target" = both ]; then
  if [ "$latest_studio" != "$compiled_studio" ]; then
    studio_changed=1
  fi
fi

effective_target=none
if [ "$target" = agent ] && [ "$agent_changed" = 1 ]; then
  effective_target=agent
elif [ "$target" = studio ] && [ "$studio_changed" = 1 ]; then
  effective_target=studio
elif [ "$target" = both ]; then
  if [ "$agent_changed" = 1 ] && [ "$studio_changed" = 1 ]; then
    effective_target=both
  elif [ "$agent_changed" = 1 ]; then
    effective_target=agent
  elif [ "$studio_changed" = 1 ]; then
    effective_target=studio
  fi
fi

if [ "$effective_target" = none ]; then
  should_build=false
else
  should_build=true
fi

printf 'requested_target=%q\n' "$target"
printf 'latest_agent=%q\n' "$latest_agent"
printf 'compiled_agent=%q\n' "$compiled_agent"
printf 'latest_studio=%q\n' "$latest_studio"
printf 'compiled_studio=%q\n' "$compiled_studio"
printf 'agent_changed=%q\n' "$agent_changed"
printf 'studio_changed=%q\n' "$studio_changed"
printf 'target=%q\n' "$effective_target"
printf 'should_build=%q\n' "$should_build"
