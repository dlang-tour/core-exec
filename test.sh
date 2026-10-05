#!/usr/bin/env bash

set -euo pipefail

dockerId=$1
current=setup
passed=0
skipped=0
detail_file=
fail_reason=
i=0
total=0
counting=0
progress='[0/0]'

on_gha() {
    [[ ${GITHUB_ACTIONS:-} == true ]]
}

start() {
    i=$((i + 1))
    current=$1
    progress=$(printf '[%*d/%d]' ${#total} "$i" "$total")
}

# "[ 1/22] ok    hello world"
line() {
    printf '%s %-6s%s' "$progress" "$1" "$current"
}

on_err() {
    local title
    title=$(line FAIL)
    if on_gha; then
        printf '::error::%s (line %s)\n' "$title" "$1"
    fi
    printf '%s (line %s)\n' "$title" "$1" >&2
}
trap 'on_err $LINENO' ERR

drop_detail() {
    if [[ -n ${detail_file:-} ]]; then
        rm -f "$detail_file"
        detail_file=
    fi
}

# GitHub only treats ::endgroup:: as a command when it starts a line.
cat_detail() {
    cat "$detail_file"
    if [[ -n $(tail -c 1 "$detail_file") ]]; then
        printf '\n'
    fi
}

pass() {
    passed=$((passed + 1))
    local title
    title=$(line ok)
    # In Actions the command output is a collapsed group. The title stays
    # visible. Locally the output is omitted and only the result line prints.
    if on_gha && [[ -n ${detail_file:-} && -s $detail_file ]]; then
        printf '::group::%s\n' "$title"
        cat_detail
        printf '::endgroup::\n'
    else
        printf '%s\n' "$title"
    fi
    drop_detail
}

skip() {
    skipped=$((skipped + 1))
    printf '%s\n' "$(line skip)"
}

report_fail() {
    local title
    title=$(line FAIL)
    if on_gha; then
        printf '::error::%s\n' "$title"
        printf '::group::%s\n' "$title"
    fi
    if [[ -n ${fail_reason:-} ]]; then
        printf '%s\n' "$fail_reason"
    fi
    if [[ -n ${detail_file:-} && -f $detail_file ]]; then
        cat_detail
    fi
    if on_gha; then
        printf '::endgroup::\n'
    else
        printf '%s\n' "$title" >&2
    fi
    drop_detail
}

run() {
    detail_file=
    fail_reason=
    if "$@"; then
        pass
    else
        report_fail
        exit 1
    fi
}

grepOutput() {
    local output_file="command_output.tmp"

    if ! "${@:1:(($# - 1))}" &> "$output_file"
    then
        fail_reason="Command failed!"
    elif ! grep -q "${@:$#}" "$output_file"
    then
        fail_reason="grep failed! pattern: ${*:$#}"
    else
        detail_file=$output_file
        return 0
    fi

    detail_file=$output_file
    return 1
}

exactOutput() {
    local output_file="command_output.tmp"
    local expect_file="command_expect.tmp"
    local raw_file="command_raw.tmp"
    local err_file="command_err.tmp"

    echo -n "${@:$#}" | xargs > "$expect_file"

    if ! "${@:1:(($# - 1))}" > "$raw_file" 2> "$err_file"
    then
        fail_reason="Command failed!"
        cat "$err_file" "$raw_file" > "$output_file"
        detail_file=$output_file
        rm -f "$expect_file" "$raw_file" "$err_file"
        return 1
    fi

    xargs < "$raw_file" > "$output_file"
    if ! diff -up "$output_file" "$expect_file" > command_diff.tmp
    then
        fail_reason="Output didn't match expected test"
        cat command_diff.tmp "$err_file" >> "$output_file"
        detail_file=$output_file
        rm -f "$expect_file" "$raw_file" "$err_file" command_diff.tmp
        return 1
    fi

    cat "$err_file" "$raw_file" > "$output_file"
    detail_file=$output_file
    rm -f "$expect_file" "$raw_file" "$err_file" command_diff.tmp
    return 0
}

encode() {
    bsource=$(echo -e "$1" | base64 -w0)
}

# invoke exact|grep expected-or-pattern [ENV=value]
invoke() {
    local mode=$1 expected=$2 envspec=${3:-}
    local status=0
    local cmd=(docker run --rm "$dockerId" "$bsource" "$expected")
    if [[ -n $envspec ]]; then
        cmd=(env "$envspec" docker run -e "${envspec%%=*}" --rm "$dockerId" "$bsource" "$expected")
    fi
    if [[ $mode == exact ]]; then
        exactOutput "${cmd[@]}" || status=$?
    else
        grepOutput "${cmd[@]}" || status=$?
    fi
    return "$status"
}

check_stdin() {
    local output
    bstdin=$(printf 'Venus\nParis\nMontreal' | base64 -w0)
    output="$(docker run --rm "$dockerId" "$bsource" "$bstdin")"
    printf '%s\n' "$output" > command_output.tmp
    detail_file=command_output.tmp
    test "$(printf "$output" | head -n1)" == "$1"
}

check_not_hello() {
    local output
    output="$(DOCKER_FLAGS="$1" docker run -e DOCKER_FLAGS --rm "$dockerId" "$bsource")"
    printf '%s\n' "$output" > command_output.tmp
    detail_file=command_output.tmp
    test "$output" != "$2"
}

matches() {
    case $1 in
        always) return 0 ;;
        dmd) [[ $is_dmd == yes ]] ;;
        ldc) [[ $is_ldc == yes ]] ;;
        nightly) [[ $is_nightly == yes ]] ;;
        *) printf 'unknown when: %s\n' "$1" >&2; exit 1 ;;
    esac
}

# t when mode name source expect [flags]
# flags starting with - are DOCKER_FLAGS. NAME=value is passed through.
# The first walk only counts cases. The second walk runs them.
t() {
    local when="$1" mode="$2" name="$3" source="$4" expect="${5:-}" spec="${6:-}"
    case $mode in
        exact | grep | stdin | ne) ;;
        *) printf 'unknown mode: %s\n' "$mode" >&2; exit 1 ;;
    esac
    if [[ $counting -eq 1 ]]; then
        total=$((total + 1))
        return
    fi

    start "$name"
    if ! matches "$when"; then
        skip
        return
    fi

    encode "$source"
    local envspec=""
    if [[ -n $spec ]]; then
        if [[ $spec == -* ]]; then
            envspec="DOCKER_FLAGS=$spec"
        else
            envspec=$spec
        fi
    fi
    case $mode in
        stdin) run check_stdin "$expect" ;;
        ne) run check_not_hello "$spec" "$expect" ;;
        *)
            if [[ -n $envspec ]]; then
                run invoke "$mode" "$expect" "$envspec"
            else
                run invoke "$mode" "$expect"
            fi
            ;;
    esac
}

is_ldc=no
is_dmd=yes
if [[ $dockerId =~ ldc ]]; then
    is_ldc=yes
    is_dmd=no
fi
is_nightly=no
if [[ $dockerId == *nightly ]]; then
    is_nightly=yes
fi

dpp_hello=$(cat <<EOF
#include <stdio.h>

void main() {
    printf("Hello World");
}
EOF
)

dpp_har=$(cat <<EOF
--- c.h
#ifndef C_H
#define C_H

#define FOO_ID(x) (x*3)

int twice(int i);

#endif

--- c.c
int twice(int i) { return i * 2; }

--- foo.dpp
#include "c.h"
void main() {
    import std.stdio;
    writeln(twice(FOO_ID(5)));  // yes, it's using a C macro here!
}
EOF
)

version_foo='void main() { import std.stdio; version(Foo) writeln("Hello World"); }'

define_tests() {
    t always exact "hello world" \
        'void main() { import std.stdio; writeln("Hello World"); }' \
        "Hello World"

    t always stdin stdin \
        'void main() { import std.algorithm, std.stdio; stdin.byLine.each!writeln;}' \
        Venus

    t always exact "version flag typo" "$version_foo" "" -version=Fooo
    t always ne "version flag Foo" "$version_foo" "Hello world" -version=Foo
    t always ne "version flags Bar and Foo" "$version_foo" "Hello world" \
        "-version=Bar -version=Foo"

    t always exact "runtime args" \
        'void main(string[] args) { import std.stdio; writeln(args[1..$]); }' \
        '["foo", "-test=bar"]' \
        'DOCKER_RUNTIME_ARGS=foo -test=bar'

    t always exact "dub hello" \
        '/++dub.sdl: name"foo"+/ void main() { import std.stdio; writeln("Hello World"); }' \
        "Hello World"

    t always grep "dub mir" \
        '/++dub.sdl: name"foo" \n dependency"mir" version="*"+/ void main() { import mir.combinatorics, std.stdio; writeln([0, 1].permutations); }' \
        '[[0, 1], [1, 0]]'

    t always grep "dub vibe-d" \
        '/++dub.sdl: name"foo" \n dependency"vibe-d" version=">=0.9.7"+/ void main() { import vibe.d, std.stdio; auto a = Json("hello world"); a.writeln; }' \
        '"hello world"'

    t always grep "dub unittest" \
        '/++dub.sdl: name"foo" \n dependency"mir" version="*"+/ unittest { import mir.combinatorics, std.stdio; writeln([0, 1].permutations); } version(unittest) {} else { void main() { } } ' \
        '[[0, 1], [1, 0]]' \
        -unittest

    t always grep "vcg-ast" \
        'void main() { foreach (i; [1, 2]) {} }' \
        __key \
        -vcg-ast

    t dmd grep asm \
        'void main() { int a; }' \
        _Dmain \
        -asm

    t ldc grep "output-ll" \
        'void main() { int a; }' \
        'define i32 @_Dmain' \
        -output-ll

    t ldc grep "output-s" \
        'void main() { int a; }' \
        '_Dmain:' \
        -output-s

    # The store is line 4 column 2, which AddressSanitizer prints in the trace.
    t ldc grep "address sanitizer" \
        $'void main() { \n int a; \n int* ap = &a + 1; \n *ap = 0; }' \
        '#0 0x[0-9a-f]* in ..main [/a-z\.]*:4:2' \
        '-fsanitize=address -g'

    t always grep html \
        '///\nvoid main(){}' \
        '<html>' \
        -D

    t always grep json \
        '///\nvoid main(){}' \
        '"file" : "onlineapp.d"' \
        -Xf=-

    t always grep har \
        '--- test.d\nvoid main(){import std.stdio; __FILE__.writeln;}' \
        test.d

    t always grep "har multiple files" \
        '--- test.d\nvoid main(){import bar; foo();}\n--- bar.d\nvoid foo(){import std.stdio; __FILE__.writeln;}' \
        bar.d

    t nightly grep "minimal runtime" \
        '--- object.d\nmodule object;\n--- bar.d\nextern(C) void main(){printf("%s", __MODULE__.ptr);\n}' \
        '`printf` is not defined' \
        '-conf= -defaultlib='

    t always exact "dpp hello" "$dpp_hello" "Hello World"
    t always exact "dpp and har" "$dpp_har" "30"
}

counting=1
define_tests
counting=0
i=0
progress=$(printf '[%*d/%d]' ${#total} 0 "$total")

printf 'Testing %s\n' "$dockerId"
define_tests

if [[ $i -ne $total ]]; then
    printf 'ran %s cases, total is %s\n' "$i" "$total" >&2
    exit 1
fi
printf '%s passed, %s skipped\n' "$passed" "$skipped"
