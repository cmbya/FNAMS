#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "${ROOT_DIR}/build"
command -v gh >/dev/null 2>&1 || { echo 'gh is required.' >&2; exit 1; }
latest_tag() { gh api "repos/$1/releases" --paginate --jq '[.[] | select(.draft == false and .prerelease == false)][0].tag_name' | head -n1; }
agent_tag=$(latest_tag NousResearch/hermes-agent)
studio_tag=$(latest_tag EKKOLearnAI/hermes-studio)
test -n "$agent_tag" -a -n "$studio_tag"
cat >"${ROOT_DIR}/build/upstream.env" <<EOF
HERMES_AGENT_TAG=${agent_tag}
HERMES_AGENT_VERSION=${agent_tag#v}
HERMES_STUDIO_TAG=${studio_tag}
HERMES_STUDIO_VERSION=${studio_tag#v}
EOF
echo "Resolved formal Releases: ${agent_tag}; ${studio_tag}."

