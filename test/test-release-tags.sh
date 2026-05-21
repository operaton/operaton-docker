#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCK_DIR="$(mktemp -d)"
MOCK_DOCKER_CALLS="${MOCK_DIR}/docker-calls.log"
trap 'rm -rf "${MOCK_DIR}"' EXIT

cat > "${MOCK_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${MOCK_DOCKER_CALLS}"
if [ "$1" = "manifest" ] && [ "$2" = "inspect" ]; then
  exit 1
fi
exit 0
EOF
chmod +x "${MOCK_DIR}/docker"

run_release() {
  local snapshot_tag_branch="$1"
  : > "${MOCK_DOCKER_CALLS}"
  PATH="${MOCK_DIR}:${PATH}" \
    MOCK_DOCKER_CALLS="${MOCK_DOCKER_CALLS}" \
    DISTRO="run" \
    VERSION="1.2.3" \
    SNAPSHOT="true" \
    SNAPSHOT_TAG_BRANCH="${snapshot_tag_branch}" \
    DOCKERHUB_USERNAME="user" \
    DOCKERHUB_PASSWORD="pass" \
    IMAGE_REPO_OPERATON="operaton/operaton" \
    GITHUB_STEP_SUMMARY="${MOCK_DIR}/summary.log" \
    bash "${ROOT_DIR}/release.sh" > /dev/null 2>&1
}

run_release "main"
grep -q -- "--tag operaton/operaton:1.2.3-SNAPSHOT" "${MOCK_DOCKER_CALLS}"
grep -q -- "--tag operaton/operaton:SNAPSHOT" "${MOCK_DOCKER_CALLS}"

run_release "release/1.0.x"
grep -q -- "--tag operaton/operaton:1.2.3-SNAPSHOT" "${MOCK_DOCKER_CALLS}"
if grep -q -- "--tag operaton/operaton:SNAPSHOT" "${MOCK_DOCKER_CALLS}"; then
  echo "SNAPSHOT tag must not be added for release branches"
  exit 1
fi
