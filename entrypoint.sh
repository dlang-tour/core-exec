#!/bin/bash

set -e
set -u
set -o pipefail

cd /sandbox
echo "$*" | base64 -d > onlineapp.d

exec timeout -s KILL ${TIMEOUT:-20} dmd -run onlineapp.d | tail -n100
