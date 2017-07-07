#!/bin/bash

set -e
set -u
set -o pipefail

cd /sandbox
echo "$1" | base64 -d > onlineapp.d

args=${DOCKER_FLAGS:-""}
if [ -z ${2:-""} ] ; then
    exec timeout -s KILL ${TIMEOUT:-20} rdmd $args onlineapp.d | tail -n100
else
    exec timeout -s KILL ${TIMEOUT:-20} bash -c "echo $2 | base64 -d | rdmd $args onlineapp.d | tail -n100"
fi
