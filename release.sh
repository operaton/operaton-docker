#!/bin/bash -eux

VERSION=${VERSION:-$(grep VERSION= Dockerfile | head -n1 | cut -d = -f 2)}
DISTRO=${DISTRO:-$(grep DISTRO= Dockerfile | cut -d = -f 2)}
SNAPSHOT=${SNAPSHOT:-$(grep SNAPSHOT= Dockerfile | cut -d = -f 2)}
PLATFORMS=${PLATFORMS:-linux/amd64}
IMAGE=${IMAGE_REGISTRY}

function build_and_push {
    local tags=("$@")
    printf -v tag_arguments -- "--tag $IMAGE:%s " "${tags[@]}"
    docker buildx build .                         \
        $tag_arguments                            \
        --build-arg DISTRO=${DISTRO}              \
        --cache-from type=gha,scope="$GITHUB_REF_NAME-$DISTRO-image" \
        --platform $PLATFORMS \
        --push

      echo "Tags released:" >> $GITHUB_STEP_SUMMARY
      printf -- "- $IMAGE:%s\n" "${tags[@]}" >> $GITHUB_STEP_SUMMARY
}

# check whether the image for distro was already released and exit in that case
if [ $(docker manifest inspect $IMAGE:${DISTRO}-${VERSION} > /dev/null ; echo $?) == '0' ]; then
    echo "Not pushing already released image"
    exit 0
fi

docker login -u "${DOCKERHUB_USERNAME}" -p "${DOCKERHUB_PASSWORD}"

tags=()

if [ "${SNAPSHOT}" = "true" ]; then
    tags+=("${DISTRO}-${VERSION}-SNAPSHOT")
    tags+=("${DISTRO}-SNAPSHOT")

    if [ "${DISTRO}" = "tomcat" ]; then
        tags+=("${VERSION}-SNAPSHOT")
        tags+=("SNAPSHOT")
    fi
else
    tags+=("${DISTRO}-${VERSION}")
    if [ "${DISTRO}" = "run" ]; then
        tags+=("${VERSION}")
        tags+=("latest")
    fi
fi

build_and_push "${tags[@]}"
