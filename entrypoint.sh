#!/bin/bash

cd /sandbox
echo "$*" | base64 -d > onlineapp.d

exec timeout -s KILL ${TIMEOUT:-20} rdmd onlineapp.d | tail -n100
