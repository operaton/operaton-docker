#!/bin/bash

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
  IMAGE_NAME=${IMAGE_REPO_OPERATON}:${PLATFORM}
elif [ "$DISTRO" == "tomcat" ]; then
  IMAGE_NAME=${IMAGE_REPO_TOMCAT}:${PLATFORM}
elif [ "$DISTRO" == "wildfly" ]; then
  IMAGE_NAME=${IMAGE_REPO_WILDFLY}:${PLATFORM}
fi

export IMAGE_NAME

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd ${DIR}

source test_helper.sh

docker compose up --force-recreate -d postgres mysql
./test-${DISTRO}.sh operaton
./test-${DISTRO}.sh operaton-mysql
./test-${DISTRO}.sh operaton-postgres
./test-${DISTRO}.sh operaton-password-file
./test-prometheus-jmx-${DISTRO}.sh operaton-prometheus-jmx
./test-debug.sh operaton-debug
docker compose down -v
cd -
