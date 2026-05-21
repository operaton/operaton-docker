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

if [ "$DISTRO" == "run" ]; then
  IMAGE=${IMAGE_REPO_OPERATON}
elif [ "$DISTRO" == "tomcat" ]; then
  IMAGE=${IMAGE_REPO_TOMCAT}
elif [ "$DISTRO" == "wildfly" ]; then
  IMAGE=${IMAGE_REPO_WILDFLY}
fi

function build_and_push {
    local tags=("$@")
    printf -v tag_arguments -- "--tag $IMAGE:%s " "${tags[@]}"
    docker buildx build .                         \
        $tag_arguments                            \
        --build-arg DISTRO=${DISTRO}              \
        --build-arg VERSION=${VERSION}            \
        --build-arg SNAPSHOT=${SNAPSHOT}          \
        --cache-from type=gha,scope="$GITHUB_REF_NAME-$DISTRO-image" \
        --platform $PLATFORMS \
        --push

      echo "Tags released:" >> $GITHUB_STEP_SUMMARY
      printf -- "- $IMAGE:%s\n" "${tags[@]}" >> $GITHUB_STEP_SUMMARY
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
            printf '%s' "${response}" | python3 -c 'import json, re, sys
data = json.load(sys.stdin)
for result in data.get("results", []):
    name = result.get("name", "")
    if re.fullmatch(r"\d+\.\d+\.\d+", name):
        print(name)'
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

# check whether the image for distro was already released and exit in that case
if [ $(docker manifest inspect $IMAGE:${VERSION} > /dev/null ; echo $?) == '0' ]; then
    echo "Not pushing already released image"
    exit 0
fi

echo "$DOCKERHUB_PASSWORD" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin

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
