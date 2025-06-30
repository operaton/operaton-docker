#!/bin/bash -ex

if [ -z "$SNAPSHOT" ]; then
  SNAPSHOT_ARGUMENT=""
else
  SNAPSHOT_ARGUMENT="--build-arg SNAPSHOT=${SNAPSHOT}"
fi

if [ -z "$VERSION" ]; then
  VERSION_ARGUMENT=""
else
  VERSION_ARGUMENT="--build-arg VERSION=${VERSION}"
fi

if [ "$DISTRO" == "run" ]; then
  IMAGE_NAME=${IMAGE_REPO_OPERATON}:${PLATFORM}
elif [ "$DISTRO" == "tomcat" ]; then
  IMAGE_NAME=${IMAGE_REPO_TOMCAT}:${PLATFORM}
elif [ "$DISTRO" == "wildfly" ]; then
  IMAGE_NAME=${IMAGE_REPO_WILDFLY}:${PLATFORM}
fi

echo "Using distro $DISTRO with repo URL $IMAGE_REPO_OPERATON"

docker buildx build .                         \
    -t "${IMAGE_NAME}"                        \
    --platform linux/${PLATFORM}              \
    --build-arg DISTRO=${DISTRO}              \
    ${VERSION_ARGUMENT}                       \
    ${SNAPSHOT_ARGUMENT}                      \
    --cache-to type=gha,scope="$GITHUB_REF_NAME-$DISTRO-image" \
    --cache-from type=gha,scope="$GITHUB_REF_NAME-$DISTRO-image" \
    --load

docker inspect "${IMAGE_NAME}" | grep "Architecture" -A2
