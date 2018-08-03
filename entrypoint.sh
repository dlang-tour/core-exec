#!/bin/bash

set -e
set -u
set -o pipefail

cd /sandbox

source=$(echo "$1" | base64 -d)
if grep -qE "#include" <<< "$source" > /dev/null 2>&1; then
    onlineapp="onlineapp.dpp"
else
    onlineapp="onlineapp.d"
fi

echo "$source" > $onlineapp


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
elif [[ $args =~ .*-Xf=-* ]] ; then
    args="${args/-Xf=-/-Xf=- -c -o-}"
fi

if grep -q "^--- .*d" "$onlineapp" > /dev/null 2>&1  ; then
    mv "$onlineapp" onlineapp.har
    har_files="$(har --dir=$PWD "onlineapp.har")"
    if ! [[ $args =~ .*-c.* ]] ; then
        with_run="-run"
    else
        with_run="-fPIC"
    fi
    # use dpp for .dpp files
    if echo "$har_files" | grep -q "[.]dpp$" ; then
        c_files=($(echo "$har_files" | grep "[.]c$" || echo ""))
        d_files=($(echo "$har_files" | grep -E "[.](dpp|d)$" || echo ""))
        other_modules=(${d_files[@]:1})
        for c_file in "${c_files[@]}" ; do
            c_out=$(echo "$c_file" | sed "s/[.]c$/.o/")
            exec timeout -s KILL ${TIMEOUT:-30} gcc -c "$c_file" -o "$c_out"  | tail -n10000
            other_modules+=("$c_out")
        done
        # TODO: cpp support
        exec timeout -s KILL ${TIMEOUT:-30} dub run dpp -q --compiler=${DLANG_EXEC} --skip-registry=all -- --compiler=${DLANG_EXEC} -g $args "${other_modules[@]}" "${d_files[0]}" | tail -n100000
        if [ "$with_run" == "-run" ] ; then
            exec timeout -s KILL ${TIMEOUT:-30} "${d_files[0]%%.*}" | tail -n10000
        fi
    else
        d_files=($(echo "$har_files" | grep "[.]d$" || echo ""))
        exec timeout -s KILL ${TIMEOUT:-30} bash -c "${DLANG_EXEC} -g $args "${d_files[@]:1}" $with_run "${d_files[0]}" | tail -n100000"
    fi
elif  grep -qE "dub[.](sdl|json):" "$onlineapp" > /dev/null 2>&1  ; then
    exec timeout -s KILL ${TIMEOUT:-30} dub -q --compiler=${DLANG_EXEC} --single --skip-registry=all "$onlineapp" | tail -n10000
elif [ ${onlineapp: -4} == ".dpp" ]; then
    exec timeout -s KILL ${TIMEOUT:-30} dub run dpp -q --compiler=${DLANG_EXEC} --skip-registry=all -- --compiler=${DLANG_EXEC} "$onlineapp" | tail -n10000
    exec timeout -s KILL ${TIMEOUT:-30} ./onlineapp | tail -n10000
else
    if ! [[ $args =~ .*-c.* ]] ; then
        args="$args -run"
    fi

    if [ $return_asm -eq 1 ] ; then
        exec timeout -s KILL ${TIMEOUT:-30} bash -c "${DLANG_EXEC} $args -g "$onlineapp" | tail -n100; \
            obj2asm onlineapp.o | $ddemangle | tail -n500000;"
    elif [[ $args =~ .*-c.* ]] ; then
        exec timeout -s KILL ${TIMEOUT:-30} bash -c "${compiler} $args "$onlineapp" | tail -n100; \
        if [ -f $return_file ] ; then \
            cat "$return_file" | $ddemangle | tail -n500000; \
        fi"
    elif [ -z ${2:-""} ] ; then
        exec timeout -s KILL ${TIMEOUT:-30} \
            bash -c 'faketty () { script -qfc "$(printf "%q " "$@")" /dev/null ; };'"faketty ${DLANG_EXEC} -color=$coloring -g $args "$onlineapp" | cat" \
            | sed 's/\r//' \
            | tail -n10000
    else
        exec timeout -s KILL ${TIMEOUT:-30} bash -c "echo $2 | base64 -d | ${DLANG_EXEC} -g $args "$onlineapp" | tail -n10000"

    fi
fi
