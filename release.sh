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
    # Only add "latest" tag if VERSION matches semantic versioning pattern `major.minor.patch`
    # In other words, avoid tagging pre-releases with suffixes like -M1
    if [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        tags+=("latest")
    fi
fi

build_and_push "${tags[@]}"
