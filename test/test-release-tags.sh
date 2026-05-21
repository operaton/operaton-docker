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

cat > "${MOCK_DIR}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${MOCK_CURL_CALLS}"

url="${!#}"

if [[ "${url}" == *"page=2"* ]]; then
  cat "${MOCK_CURL_PAGE_2}"
  exit 0
fi

cat "${MOCK_CURL_PAGE_1}"
EOF
chmod +x "${MOCK_DIR}/curl"

run_release() {
  local snapshot_tag_branch="$1"
  local version="$2"
  local snapshot="$3"
  : > "${MOCK_DOCKER_CALLS}"
  : > "${MOCK_CURL_CALLS}"
  PATH="${MOCK_DIR}:${PATH}" \
    MOCK_DOCKER_CALLS="${MOCK_DOCKER_CALLS}" \
    MOCK_CURL_CALLS="${MOCK_CURL_CALLS}" \
    MOCK_CURL_PAGE_1="${MOCK_CURL_PAGE_1}" \
    MOCK_CURL_PAGE_2="${MOCK_CURL_PAGE_2}" \
    DISTRO="run" \
    VERSION="${version}" \
    SNAPSHOT="${snapshot}" \
    SNAPSHOT_TAG_BRANCH="${snapshot_tag_branch}" \
    DOCKERHUB_USERNAME="user" \
    DOCKERHUB_PASSWORD="pass" \
    IMAGE_REPO_OPERATON="operaton/operaton" \
    GITHUB_STEP_SUMMARY="${MOCK_DIR}/summary.log" \
    bash "${ROOT_DIR}/release.sh" > /dev/null 2>&1
}

MOCK_CURL_CALLS="${MOCK_DIR}/curl-calls.log"
MOCK_CURL_PAGE_1="${MOCK_DIR}/curl-page-1.json"
MOCK_CURL_PAGE_2="${MOCK_DIR}/curl-page-2.json"

cat > "${MOCK_CURL_PAGE_1}" <<'EOF'
{"results":[{"name":"2.1.0"},{"name":"latest"},{"name":"2.0.3"}],"next":"https://hub.docker.com/v2/namespaces/operaton/repositories/operaton/tags?page=2"}
EOF

cat > "${MOCK_CURL_PAGE_2}" <<'EOF'
{"results":[{"name":"1.9.9"},{"name":"2.1.0-M1"}],"next":null}
EOF

run_release "main" "1.2.3" "true"
grep -q -- "--tag operaton/operaton:1.2.3-SNAPSHOT" "${MOCK_DOCKER_CALLS}"
grep -q -- "--tag operaton/operaton:SNAPSHOT" "${MOCK_DOCKER_CALLS}"
if [ -s "${MOCK_CURL_CALLS}" ]; then
  echo "curl must not be called for snapshot releases"
  exit 1
fi

run_release "release/1.0.x" "1.2.3" "true"
grep -q -- "--tag operaton/operaton:1.2.3-SNAPSHOT" "${MOCK_DOCKER_CALLS}"
if grep -q -- "--tag operaton/operaton:SNAPSHOT" "${MOCK_DOCKER_CALLS}"; then
  echo "SNAPSHOT tag must not be added for release branches"
  exit 1
fi

run_release "main" "2.0.4" "false"
grep -q -- "--tag operaton/operaton:2.0.4" "${MOCK_DOCKER_CALLS}"
if grep -q -- "--tag operaton/operaton:latest" "${MOCK_DOCKER_CALLS}"; then
  echo "latest tag must not be added when a higher release already exists"
  exit 1
fi

run_release "main" "2.1.1" "false"
grep -q -- "--tag operaton/operaton:2.1.1" "${MOCK_DOCKER_CALLS}"
grep -q -- "--tag operaton/operaton:latest" "${MOCK_DOCKER_CALLS}"
grep -q -- "page=2" "${MOCK_CURL_CALLS}"

run_release "main" "2.1.1-M1" "false"
grep -q -- "--tag operaton/operaton:2.1.1-M1" "${MOCK_DOCKER_CALLS}"
if grep -q -- "--tag operaton/operaton:latest" "${MOCK_DOCKER_CALLS}"; then
  echo "latest tag must not be added for pre-releases"
  exit 1
fi
if [ -s "${MOCK_CURL_CALLS}" ]; then
  echo "curl must not be called for pre-releases"
  exit 1
fi
