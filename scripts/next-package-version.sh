#!/usr/bin/env bash
set -euo pipefail

# Return the next fnOS package version for one independent application.
# FNAMS intentionally rolls 0.1.9 to 0.2.0 instead of creating 0.1.10.
target=${1:?target is required: agent or studio}
fallback=${2:?fallback version is required}
case "$target" in
  agent|studio) ;;
  *) echo "target must be agent or studio (got: $target)" >&2; exit 2 ;;
esac

latest=""
if command -v gh >/dev/null 2>&1; then
  repository=${GITHUB_REPOSITORY:-cmbya/FNAMS}
  latest=$(
    gh api "repos/${repository}/releases?per_page=100" --paginate \
      --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name' \
      2>/dev/null \
      | while IFS= read -r tag; do
          case "$tag" in
            "${target}-v"*) printf '%s\n' "${tag#${target}-v}" ;;
            v*) printf '%s\n' "${tag#v}" ;;
          esac
        done \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
      | sort -V \
      | tail -n 1
  ) || true
fi

current=${latest:-$fallback}
if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Cannot determine current $target package version: $current" >&2
  exit 1
fi

IFS=. read -r major minor patch <<< "$current"
if (( patch >= 9 )); then
  minor=$((minor + 1))
  patch=0
else
  patch=$((patch + 1))
fi
printf '%d.%d.%d\n' "$major" "$minor" "$patch"
