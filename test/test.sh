#!/bin/bash -xeu

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
