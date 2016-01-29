#!/bin/bash

cd /sandbox
echo "$*" | base64 -d > onlineapp.d

exec rdmd onlineapp.d
