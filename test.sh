#!/usr/bin/env bash

set -euvo pipefail

dockerId=$1

err_report() {
    echo "Error on line $1"
}
trap 'err_report $LINENO' ERR

grepOutput() {
    local output_file="command_output.tmp"

    if ! "${@:1:(($# - 1))}" &> $output_file
    then
        echo "Command failed!"

    elif ! grep -q "${@:$#}" $output_file
    then
        echo "grep failed!"

    else
        rm $output_file
        return 0
    fi

    cat $output_file
    rm $output_file
    exit 1
}

# simple hello world
source='void main() { import std.stdio; writeln("Hello World"); }'
bsource=$(echo $source | base64 -w0)
[ "$(docker run --rm $dockerId $bsource)" == "Hello World" ]

# stdin
source='void main() { import std.algorithm, std.stdio; stdin.byLine.each!writeln;}'
bsource=$(echo $source | base64 -w0)
bstdin=$(printf 'Venus\nParis\nMontreal' | base64 -w0)
output="$(docker run --rm $dockerId $bsource $bstdin)"
[ "$(printf "$output" | head -n1)" == "Venus" ]

# custom arguments
source='void main() { import std.stdio; version(Foo) writeln("Hello World"); }'
bsource=$(echo $source | base64 -w0)
[ "$(DOCKER_FLAGS="-version=Fooo" docker run -e DOCKER_FLAGS --rm $dockerId $bsource)" == "" ]
[ "$(DOCKER_FLAGS="-version=Foo" docker run -e DOCKER_FLAGS --rm $dockerId $bsource)" != "Hello world" ]
[ "$(DOCKER_FLAGS="-version=Bar -version=Foo" docker run -e DOCKER_FLAGS --rm $dockerId $bsource)" != "Hello world" ]

# test runtime args
source='void main(string[] args) { import std.stdio; writeln(args[1..$]); }'
bsource=$(echo $source | base64 -w0)
[ "$(DOCKER_RUNTIME_ARGS="foo -test=bar" docker run -e DOCKER_RUNTIME_ARGS --rm $dockerId $bsource)" == "[\"foo\", \"-test=bar\"]" ]

## dub file
source='/++dub.sdl: name"foo"+/ void main() { import std.stdio; writeln("Hello World"); }'
bsource=$(echo "$source" | base64 -w0)
[ "$(docker run --rm $dockerId $bsource)" == "Hello World" ]

source="/++dub.sdl: name\"foo\" \n dependency\"mir\" version=\"*\"+/ void main() { import mir.combinatorics, std.stdio; writeln([0, 1].permutations); }"
bsource=$(echo -e "$source" | base64 -w0)
[ "$(docker run --rm "$dockerId" "$bsource")" == "[[0, 1], [1, 0]]" ]

source="/++dub.sdl: name\"foo\" \n dependency\"vibe-d\" version=\">=0.9.7\"+/ void main() { import vibe.d, std.stdio; Json a; a.writeln; }"
bsource=$(echo -e "$source" | base64 -w0)
[ "$(docker run --rm "$dockerId" "$bsource")" == "null" ]

## dub file with unittest
source="/++dub.sdl: name\"foo\" \n dependency\"mir\" version=\"*\"+/ unittest { import mir.combinatorics, std.stdio; writeln([0, 1].permutations); } version(unittest) {} else { void main() { } } "
bsource=$(echo -e "$source" | base64 -w0)
[ "$(DOCKER_FLAGS="-unittest" docker run -e DOCKER_FLAGS --rm $dockerId $bsource)" == "[[0, 1], [1, 0]]" ]

# Test -c
source='void main() { static assert(0); }'
bsource=$(echo $source | base64 -w0)

# Test -vcg-ast
source='void main() { foreach (i; [1, 2]) {} }'
bsource=$(echo $source | base64 -w0)
grepOutput docker run -e DOCKER_FLAGS="-vcg-ast" --rm $dockerId $bsource "__key"

# Check -asm (DMD-only)
if [[ ! $dockerId =~ "ldc" ]] ; then
    source='void main() { int a; }'
    bsource=$(echo $source | base64 -w0)
    grepOutput docker run -e DOCKER_FLAGS="-asm" --rm $dockerId $bsource "_Dmain"
fi

# Check -ouput-ll and -output-s
if [[ $dockerId =~ "ldc" ]] ; then
    source='void main() { int a; }'
    bsource=$(echo $source | base64 -w0)
    grepOutput docker run -e DOCKER_FLAGS="-output-ll" --rm $dockerId $bsource 'define i32 @_Dmain'
    grepOutput docker run -e DOCKER_FLAGS="-output-s" --rm $dockerId $bsource '_Dmain:'
fi

# Check AddressSanitizer output with line numbers (LDC-only)
if [[ $dockerId =~ "ldc" ]] ; then
    source=$'void main() { \n int a; \n int* ap = &a + 1; \n *ap = 0; }'
    #                                                        ^ line 4 column 2
    bsource=$(echo "$source" | base64 -w0)
    grepOutput docker run -e DOCKER_FLAGS="-fsanitize=address -g" --rm $dockerId $bsource '#0 0x[0-9a-f]* in ..main [/a-z\.]*:4:2'
fi

# Check HTML output
source='///\nvoid main(){}'
bsource=$(echo $source | base64 -w0)
grepOutput docker run -e DOCKER_FLAGS="-D" --rm $dockerId $bsource "<html>"

# Check JSON output
source='///\nvoid main(){}'
bsource=$(echo $source | base64 -w0)
grepOutput docker run -e DOCKER_FLAGS="-Xf=-" --rm $dockerId $bsource '"file" : "onlineapp.d"'

# Check Har
source="--- test.d\nvoid main(){import std.stdio; __FILE__.writeln;}"
bsource=$(echo -e "$source" | base64 -w0)
grepOutput docker run --rm $dockerId $bsource "test.d"

# Check har with multiple files
source="--- test.d\nvoid main(){import bar; foo();}\n--- bar.d\nvoid foo(){import std.stdio; __FILE__.writeln;}"
bsource=$(echo -e "$source" | base64 -w0)
grepOutput docker run --rm $dockerId $bsource "bar.d"

# Har - minimal runtime
# Only works on dmd-nightly for now
if [[ $1 = *nightly ]] ; then
source="--- object.d\nmodule object;\n--- bar.d\nextern(C) void main(){printf(\"%s\", __MODULE__.ptr);\n}"
bsource=$(echo -e "$source" | base64 -w0)
grepOutput docker run -e DOCKER_FLAGS="-conf= -defaultlib=" --rm $dockerId $bsource '`printf` is not defined'
fi

# Check dpp Hello World
source=$(cat <<EOF
#include <stdio.h>

void main() {
    printf("Hello World");
}
EOF
)
bsource=$(echo "$source" | base64 -w0)
[ "$(docker run --rm $dockerId $bsource)" == "Hello World" ]

# Check dpp Hello World with HAR
source=$(cat <<EOF
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
bsource=$(echo "$source" | base64 -w0)
[ "$(docker run --rm $dockerId $bsource)" == "30" ]
