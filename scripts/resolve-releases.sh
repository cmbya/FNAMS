#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT_DIR="${ROOT_DIR}/build"
mkdir -p "${OUT_DIR}"
command -v gh >/dev/null 2>&1 || { echo 'gh is required to resolve formal Releases.' >&2; exit 1; }

latest_tag() {
  gh api "repos/$1/releases" --jq '[.[] | select(.draft == false and .prerelease == false)][0].tag_name'
}

agent_tag=$(latest_tag NousResearch/hermes-agent)
studio_tag=$(latest_tag EKKOLearnAI/hermes-studio)
test -n "${agent_tag}" -a -n "${studio_tag}"

cat >"${OUT_DIR}/upstream.env" <<EOF
HERMES_AGENT_TAG=${agent_tag}
HERMES_AGENT_VERSION=${agent_tag#v}
HERMES_STUDIO_TAG=${studio_tag}
HERMES_STUDIO_VERSION=${studio_tag#v}
EOF
printf '%s\n' "Resolved formal Releases: Hermes Agent ${agent_tag}; Hermes Studio ${studio_tag}."
