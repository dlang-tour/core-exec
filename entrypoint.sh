#!/bin/bash

set -e
set -u
set -o pipefail

cd /sandbox
echo "$1" | base64 -d > onlineapp.d

args=${DOCKER_FLAGS:-""}
coloring=${DOCKER_COLOR:-"off"}
export TERM="dtour"
compiler="${DLANG_EXEC}"
return_asm=0
return_file=
ddemangle="cat"
if [[ $args =~ .*-asm.* ]] ; then
    args="${args/-asm/-c}"
    return_asm=1
    ddemangle="ddemangle"
elif [[ $args =~ .*-D.* ]] ; then
    args="${args/-D/-D -c -o-}"
    return_file="onlineapp.html"
elif [[ $args =~ .*-output-s.* ]] ; then
    args="${args/-output-s/-output-s -c}"
    compiler=ldc2
    return_file="onlineapp.s"
    ddemangle="ddemangle"
elif [[ $args =~ .*-output-ll.* ]] ; then
    args="${args/-output-ll/-output-ll -c}"
    compiler=ldc2
    return_file="onlineapp.ll"
    ddemangle="ddemangle"
elif [[ $args =~ .*-vcg-ast.* ]] ; then
    args="${args/-vcg-ast/-vcg-ast -c -o-}"
    return_file="onlineapp.d.cg"
elif [[ $args =~ .*-c.* ]] ; then
    args="${args/-c/-c -o-}"
fi

if  grep -qE "dub[.](sdl|json):" onlineapp.d > /dev/null 2>&1  ; then
    exec timeout -s KILL ${TIMEOUT:-30} dub -q --compiler=${DLANG_EXEC} --single --skip-registry=all onlineapp.d | tail -n10000
elif [ $return_asm -eq 1 ] ; then
    exec timeout -s KILL ${TIMEOUT:-30} bash -c "${DLANG_EXEC} $args -g onlineapp.d | tail -n100; \
        obj2asm onlineapp.o | $ddemangle | tail -n500000;"
elif [[ $args =~ .*-c.* ]] ; then
    exec timeout -s KILL ${TIMEOUT:-30} bash -c "${compiler} $args onlineapp.d | tail -n100; \
    if [ -f $return_file ] ; then \
        cat "$return_file" | $ddemangle | tail -n500000; \
    fi"
elif [ -z ${2:-""} ] ; then
    exec timeout -s KILL ${TIMEOUT:-30} \
        bash -c 'faketty () { script -qfc "$(printf "%q " "$@")" /dev/null ; };'"faketty ${DLANG_EXEC} $args -color=$coloring -g -run onlineapp.d | cat" \
        | sed 's/\r//' \
        | tail -n10000
else
    exec timeout -s KILL ${TIMEOUT:-30} bash -c "echo $2 | base64 -d | ${DLANG_EXEC} $args -g -run onlineapp.d | tail -n10000"
fi
