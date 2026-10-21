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
  [ "${MOCK_RELEASED:-false}" = "true" ]
  exit
fi
if [ "$1" = "buildx" ] && [ "$2" = "build" ]; then
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--metadata-file" ]; then
      echo '{"containerimage.digest":"sha256:index"}' > "$2"
    fi
    shift
  done
  exit 0
fi
if [ "$1" = "buildx" ] && [ "$2" = "imagetools" ]; then
  cat <<'JSON'
{"manifests":[
  {"digest":"sha256:arm","platform":{"architecture":"arm64","os":"linux"}},
  {"digest":"sha256:amd","platform":{"architecture":"amd64","os":"linux"}},
  {"digest":"sha256:att","platform":{"architecture":"unknown","os":"unknown"}}
]}
JSON
  exit 0
fi
exit 0
EOF
chmod +x "${MOCK_DIR}/docker"

cat > "${MOCK_DIR}/trivy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${MOCK_SBOM_CALLS}"
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output" ]; then
    echo '{"bomFormat":"CycloneDX","components":[],"vulnerabilities":[]}' > "$2"
  fi
  shift
done
EOF
chmod +x "${MOCK_DIR}/trivy"

# Attestations are remembered per image reference, so that verify-attestation
# only succeeds for images that were attested before
cat > "${MOCK_DIR}/cosign" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "cosign $*" >> "${MOCK_SBOM_CALLS}"
if [ "$1" = "attest" ]; then
  echo "${!#}" >> "${MOCK_ATTESTED}"
elif [ "$1" = "verify-attestation" ]; then
  grep -qxF -- "${!#}" "${MOCK_ATTESTED}"
fi
EOF
chmod +x "${MOCK_DIR}/cosign"

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
  local java_version="${4:-17}"
  : > "${MOCK_DOCKER_CALLS}"
  : > "${MOCK_CURL_CALLS}"
  : > "${MOCK_SBOM_CALLS}"
  rm -rf "${MOCK_DIR}/sbom"
  PATH="${MOCK_DIR}:${PATH}" \
    MOCK_DOCKER_CALLS="${MOCK_DOCKER_CALLS}" \
    MOCK_CURL_CALLS="${MOCK_CURL_CALLS}" \
    MOCK_CURL_PAGE_1="${MOCK_CURL_PAGE_1}" \
    MOCK_CURL_PAGE_2="${MOCK_CURL_PAGE_2}" \
    MOCK_SBOM_CALLS="${MOCK_SBOM_CALLS}" \
    MOCK_ATTESTED="${MOCK_ATTESTED}" \
    SBOM_DIR="${MOCK_DIR}/sbom" \
    GITHUB_WORKFLOW_REF="operaton/operaton-docker/.github/workflows/build-test-and-publish.yml@refs/heads/main" \
    DISTRO="run" \
    VERSION="${version}" \
    SNAPSHOT="${snapshot}" \
    JAVA_VERSION="${java_version}" \
    SNAPSHOT_TAG_BRANCH="${snapshot_tag_branch}" \
    DOCKERHUB_USERNAME="user" \
    DOCKERHUB_PASSWORD="pass" \
    IMAGE_REPO_OPERATON="operaton/operaton" \
    GITHUB_STEP_SUMMARY="${MOCK_DIR}/summary.log" \
    bash "${ROOT_DIR}/release.sh" > /dev/null 2>&1
}

MOCK_CURL_CALLS="${MOCK_DIR}/curl-calls.log"
MOCK_SBOM_CALLS="${MOCK_DIR}/sbom-calls.log"
MOCK_ATTESTED="${MOCK_DIR}/attested.log"
: > "${MOCK_ATTESTED}"
MOCK_CURL_PAGE_1="${MOCK_DIR}/curl-page-1.json"
MOCK_CURL_PAGE_2="${MOCK_DIR}/curl-page-2.json"

cat > "${MOCK_CURL_PAGE_1}" <<'EOF'
{"results":[{"name":"2.1.0"},{"name":"latest"},{"name":"2.0.3"}],"next":"https://hub.docker.com/v2/namespaces/operaton/repositories/operaton/tags?page=2"}
EOF
# The mocked "latest" tag verifies that release.sh ignores non-semantic tags.

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
grep -q -- "--tag operaton/operaton:2.1.1-jdk17 " "${MOCK_DOCKER_CALLS}"
grep -q -- "--tag operaton/operaton:latest-jdk17 " "${MOCK_DOCKER_CALLS}"

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

run_release "main" "2.1.1" "false" "21"
grep -q -- "--tag operaton/operaton:2.1.1-jdk21" "${MOCK_DOCKER_CALLS}"
grep -q -- "--tag operaton/operaton:latest-jdk21" "${MOCK_DOCKER_CALLS}"
grep -q -- "--build-arg JAVA_VERSION=21" "${MOCK_DOCKER_CALLS}"
if grep -q -- "jdk17" "${MOCK_DOCKER_CALLS}"; then
  echo "jdk17 tags must only be added for Java 17"
  exit 1
fi
grep -q -- "manifest inspect operaton/operaton:2.1.1-jdk21" "${MOCK_DOCKER_CALLS}"

# Java 17 job already pushed 2.2.0, the Java 21 job must still get latest-jdk21
cat > "${MOCK_CURL_PAGE_1}" <<'JSON'
{"results":[{"name":"2.2.0"},{"name":"2.2.0-jdk17"},{"name":"2.1.0-jdk21"},{"name":"3.0.0-jdk25"}],"next":null}
JSON
run_release "main" "2.2.0" "false" "21"
grep -q -- "--tag operaton/operaton:latest-jdk21" "${MOCK_DOCKER_CALLS}"

run_release "main" "2.0.5" "false" "21"
if grep -q -- "--tag operaton/operaton:latest-jdk21" "${MOCK_DOCKER_CALLS}"; then
  echo "latest-jdk21 must not be added when a higher jdk21 release already exists"
  exit 1
fi

# Each platform image gets an SBOM attestation, the provenance manifest does not
: > "${MOCK_ATTESTED}"
run_release "main" "2.3.0" "false"
grep -q -- "--metadata-file" "${MOCK_DOCKER_CALLS}"
grep -q -- "buildx imagetools inspect --raw operaton/operaton@sha256:index" "${MOCK_DOCKER_CALLS}"
grep -q -- "--format cyclonedx --output ${MOCK_DIR}/sbom/operaton-operaton-2.3.0-linux-amd64.cdx.json operaton/operaton@sha256:amd" "${MOCK_SBOM_CALLS}"
grep -q -- "--format cyclonedx --output ${MOCK_DIR}/sbom/operaton-operaton-2.3.0-linux-arm64.cdx.json operaton/operaton@sha256:arm" "${MOCK_SBOM_CALLS}"
grep -q -- "cosign attest --yes --type cyclonedx --predicate ${MOCK_DIR}/sbom/operaton-operaton-2.3.0-linux-amd64.cdx.json operaton/operaton@sha256:amd" "${MOCK_SBOM_CALLS}"
grep -q -- "cosign attest --yes --type cyclonedx --predicate ${MOCK_DIR}/sbom/operaton-operaton-2.3.0-linux-arm64.cdx.json operaton/operaton@sha256:arm" "${MOCK_SBOM_CALLS}"
grep -qF -- "--certificate-identity-regexp ^https://github\\.com/operaton/operaton-docker/\\.github/workflows/build-test-and-publish\\.yml@" "${MOCK_SBOM_CALLS}"
if grep -q -- "sha256:att" "${MOCK_SBOM_CALLS}"; then
  echo "Provenance manifests must not get an SBOM attestation"
  exit 1
fi
if grep -q -- "vulnerabilities" "${MOCK_DIR}/sbom/operaton-operaton-2.3.0-linux-amd64.cdx.json"; then
  echo "The vulnerabilities section must be removed from the SBOM"
  exit 1
fi

# A re-run for an already released image adds missing attestations only
echo "operaton/operaton@sha256:amd" > "${MOCK_ATTESTED}"
MOCK_RELEASED=true run_release "main" "2.3.0" "false"
if grep -q -- "buildx build" "${MOCK_DOCKER_CALLS}"; then
  echo "Already released images must not be rebuilt"
  exit 1
fi
grep -q -- "buildx imagetools inspect --raw operaton/operaton:2.3.0" "${MOCK_DOCKER_CALLS}"
grep -q -- "cosign attest .* operaton/operaton@sha256:arm" "${MOCK_SBOM_CALLS}"
if grep -q -- "cosign attest .* operaton/operaton@sha256:amd" "${MOCK_SBOM_CALLS}"; then
  echo "Existing attestations must not be duplicated"
  exit 1
fi
