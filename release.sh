#!/bin/bash -eux

if [ -z "$DISTRO" ]; then
  echo "DISTRO is not set"
  exit 1
fi
if [ -z "$VERSION" ]; then
  echo "VERSION is not set"
  exit 1
fi
if [ -z "$SNAPSHOT" ]; then
  echo "SNAPSHOT is not set"
  exit 1
fi

PLATFORMS=${PLATFORMS:-linux/amd64}

JAVA_VERSION=${JAVA_VERSION:-17}
if [ "$JAVA_VERSION" == "17" ]; then
  JAVA_TAG_SUFFIX=""
else
  JAVA_TAG_SUFFIX="-jdk${JAVA_VERSION}"
fi

if [ "$DISTRO" == "run" ]; then
  IMAGE=${IMAGE_REPO_OPERATON}
elif [ "$DISTRO" == "tomcat" ]; then
  IMAGE=${IMAGE_REPO_TOMCAT}
elif [ "$DISTRO" == "wildfly" ]; then
  IMAGE=${IMAGE_REPO_WILDFLY}
fi

SBOM_DIR=${SBOM_DIR:-sbom}

function build_and_push {
    local tag tags=() metadata_file index_digest
    for tag in "$@"; do
        tags+=("${tag}${JAVA_TAG_SUFFIX}")
        # The default Java version is also published with an explicit suffix
        if [ "$JAVA_VERSION" == "17" ]; then
            tags+=("${tag}-jdk17")
        fi
    done
    printf -v tag_arguments -- "--tag $IMAGE:%s " "${tags[@]}"
    metadata_file="$(mktemp)"
    docker buildx build .                         \
        $tag_arguments                            \
        --build-arg DISTRO=${DISTRO}              \
        --build-arg VERSION=${VERSION}            \
        --build-arg SNAPSHOT=${SNAPSHOT}          \
        --build-arg JAVA_VERSION=${JAVA_VERSION}  \
        --cache-from type=gha,scope="$GITHUB_REF_NAME-$DISTRO-jdk$JAVA_VERSION-image" \
        --platform $PLATFORMS \
        --metadata-file "${metadata_file}" \
        --push

      echo "Tags released:" >> $GITHUB_STEP_SUMMARY
      printf -- "- $IMAGE:%s\n" "${tags[@]}" >> $GITHUB_STEP_SUMMARY

    # Attest the pushed digest rather than a tag, which could have moved meanwhile
    index_digest="$(python3 -c 'import json, sys
print(json.load(open(sys.argv[1]))["containerimage.digest"])' "${metadata_file}")"
    attest_sboms "${IMAGE}@${index_digest}" "${tags[0]}"
}

# Prints "<digest> <os>/<arch>" for each platform image of a multi-platform
# image, skipping the provenance manifests buildx adds as "unknown/unknown"
function list_platform_images {
    docker buildx imagetools inspect --raw "$1" | python3 -c 'import json, sys
for manifest in json.load(sys.stdin).get("manifests", []):
    platform = manifest.get("platform", {})
    if platform.get("os", "unknown") != "unknown":
        print(manifest["digest"], platform["os"] + "/" + platform["architecture"])'
}

# Verifies that the image has a CycloneDX attestation signed by this workflow
function verify_sbom_attestation {
    local workflow="https://github.com/${GITHUB_WORKFLOW_REF%@*}@"
    cosign verify-attestation                                              \
        --type cyclonedx                                                   \
        --certificate-identity-regexp "^${workflow//./\\.}"                \
        --certificate-oidc-issuer https://token.actions.githubusercontent.com \
        "$1" > /dev/null
}

# Generates a CycloneDX SBOM for each platform image with trivy, covering the
# OS packages and the JRE of the base image as well as the Operaton libraries,
# and publishes it as a keyless signed attestation next to the image
function attest_sboms {
    local image_ref="$1" label="$2" platform_images line digest platform sbom attempt
    platform_images="$(list_platform_images "${image_ref}")"
    if [ -z "${platform_images}" ]; then
        echo "No platform images found for ${image_ref}" >&2
        exit 1
    fi

    mkdir -p "${SBOM_DIR}"
    echo "SBOM attestations:" >> $GITHUB_STEP_SUMMARY
    mapfile -t platform_images <<< "${platform_images}"
    for line in "${platform_images[@]}"; do
        read -r digest platform <<< "${line}"

        # Re-runs of the workflow must not stack up duplicate attestations
        if verify_sbom_attestation "${IMAGE}@${digest}" 2> /dev/null; then
            echo "SBOM attestation for ${IMAGE}@${digest} already exists"
            echo "- ${platform}: \`${IMAGE}@${digest}\` (already attested)" >> $GITHUB_STEP_SUMMARY
            continue
        fi

        sbom="${SBOM_DIR}/${IMAGE//\//-}-${label}-${platform//\//-}.cdx.json"
        # No "--scanners vuln": like the SBOMs of operaton/operaton, this is an
        # inventory only. Trivy still writes an empty vulnerabilities section,
        # which is dropped as well.
        trivy image --quiet --image-src remote --format cyclonedx \
            --output "${sbom}" "${IMAGE}@${digest}"
        python3 -c 'import json, sys
with open(sys.argv[1]) as file:
    sbom = json.load(file)
sbom.pop("vulnerabilities", None)
with open(sys.argv[1], "w") as file:
    json.dump(sbom, file, indent=2)' "${sbom}"

        cosign attest --yes --type cyclonedx --predicate "${sbom}" "${IMAGE}@${digest}"
        # Docker Hub lists new referrers with a short delay
        for attempt in 1 2 3 4 5 6; do
            if verify_sbom_attestation "${IMAGE}@${digest}"; then
                break
            elif [ "${attempt}" -eq 6 ]; then
                echo "SBOM attestation for ${IMAGE}@${digest} could not be verified" >&2
                exit 1
            fi
            sleep "${ATTESTATION_RETRY_DELAY:-10}"
        done
        echo "- ${platform}: \`${IMAGE}@${digest}\`" >> $GITHUB_STEP_SUMMARY
    done
}

function get_highest_release_version {
    local namespace repository url response next_url highest_version="" candidate

    namespace="${IMAGE%%/*}"
    repository="${IMAGE#*/}"
    url="https://hub.docker.com/v2/namespaces/${namespace}/repositories/${repository}/tags?page_size=100"

    while [ -n "${url}" ]; do
        response="$(curl --fail --silent --show-error "${url}")" || return 1

        while IFS= read -r candidate; do
            if [ -z "${candidate}" ]; then
                continue
            fi

            if [ -z "${highest_version}" ] || [ "$(printf '%s\n%s\n' "${highest_version}" "${candidate}" | sort -V | tail -n1)" = "${candidate}" ]; then
                highest_version="${candidate}"
            fi
        done < <(
            # Only tags of the same Java version count, printed without their suffix
            printf '%s' "${response}" | python3 -c 'import json, re, sys
data = json.load(sys.stdin)
for result in data.get("results", []):
    name = result.get("name", "")
    match = re.fullmatch(r"(\d+\.\d+\.\d+)" + re.escape(sys.argv[1]), name)
    if match:
        print(match.group(1))' "${JAVA_TAG_SUFFIX}"
        )

        next_url="$(
            printf '%s' "${response}" | python3 -c 'import json, sys
print(json.load(sys.stdin).get("next") or "")'
        )"
        url="${next_url}"
    done

    printf '%s' "${highest_version}"
}

function should_tag_latest {
    local highest_version

    if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi

    highest_version="$(get_highest_release_version)" || {
        echo "Unable to determine highest released version for ${IMAGE}" >&2
        exit 1
    }

    if [ -z "${highest_version}" ]; then
        return 0
    fi

    [ "$(printf '%s\n%s\n' "${highest_version}" "${VERSION}" | sort -V | tail -n1)" = "${VERSION}" ] && [ "${VERSION}" != "${highest_version}" ]
}

echo "$DOCKERHUB_PASSWORD" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

# check whether the image for distro was already released and exit in that case
if [ $(docker manifest inspect $IMAGE:${VERSION}${JAVA_TAG_SUFFIX} > /dev/null ; echo $?) == '0' ]; then
    echo "Not pushing already released image"
    # A previous run may have pushed the image but failed to attest its SBOM
    attest_sboms "$IMAGE:${VERSION}${JAVA_TAG_SUFFIX}" "${VERSION}${JAVA_TAG_SUFFIX}"
    exit 0
fi

tags=()

if [ "${SNAPSHOT}" = "true" ]; then
    tags+=("${VERSION}-SNAPSHOT")
    SNAPSHOT_TAG_BRANCH="${SNAPSHOT_TAG_BRANCH:-${GITHUB_REF_NAME:-}}"
    if [ "${SNAPSHOT_TAG_BRANCH}" = "main" ]; then
        tags+=("SNAPSHOT")
    fi
else
    tags+=("${VERSION}")
    if should_tag_latest; then
        tags+=("latest")
    fi
fi

build_and_push "${tags[@]}"
