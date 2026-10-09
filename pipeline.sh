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

JAVA_VERSION=${JAVA_VERSION:-17}
if [ "$JAVA_VERSION" == "17" ]; then
  JAVA_TAG_SUFFIX=""
else
  JAVA_TAG_SUFFIX="-jdk${JAVA_VERSION}"
fi

# The gha cache only works inside GitHub Actions
if [ "$GITHUB_ACTIONS" == "true" ]; then
  CACHE_ARGUMENTS="--cache-to type=gha,scope=$GITHUB_REF_NAME-$DISTRO-jdk$JAVA_VERSION-image --cache-from type=gha,scope=$GITHUB_REF_NAME-$DISTRO-jdk$JAVA_VERSION-image"
else
  CACHE_ARGUMENTS=""
fi

if [ -z "$IMAGE_REPO_OPERATON" ]; then
  IMAGE_REPO_OPERATON="operaton/operaton"
fi
if [ -z "$IMAGE_REPO_TOMCAT" ]; then
  IMAGE_REPO_TOMCAT="operaton/operaton-tomcat"
fi
if [ -z "$IMAGE_REPO_WILDFLY" ]; then
  IMAGE_REPO_WILDFLY="operaton/operaton-wildfly"
fi

if [ "$DISTRO" == "run" ]; then
  IMAGE_NAME=${IMAGE_REPO_OPERATON}:${PLATFORM}${JAVA_TAG_SUFFIX}
elif [ "$DISTRO" == "tomcat" ]; then
  IMAGE_NAME=${IMAGE_REPO_TOMCAT}:${PLATFORM}${JAVA_TAG_SUFFIX}
elif [ "$DISTRO" == "wildfly" ]; then
  IMAGE_NAME=${IMAGE_REPO_WILDFLY}:${PLATFORM}${JAVA_TAG_SUFFIX}
fi

docker buildx build .                         \
    -t "${IMAGE_NAME}"                        \
    --platform linux/${PLATFORM}              \
    --build-arg DISTRO=${DISTRO}              \
    --build-arg JAVA_VERSION=${JAVA_VERSION}  \
    ${VERSION_ARGUMENT}                       \
    ${SNAPSHOT_ARGUMENT}                      \
    ${CACHE_ARGUMENTS}                        \
    --load

docker inspect "${IMAGE_NAME}" | grep "Architecture" -A2
