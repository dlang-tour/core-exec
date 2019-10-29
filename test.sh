#!/usr/bin/env bash

set -e
set -u
set -o pipefail

dockerId=$1

err_report() {
    echo "Error on line $1"
}
trap 'err_report $LINENO' ERR

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

## dub file
source='/++dub.sdl: name"foo"+/ void main() { import std.stdio; writeln("Hello World"); }'
bsource=$(echo "$source" | base64 -w0)
[ "$(docker run --rm $dockerId $bsource)" == "Hello World" ]

source="/++dub.sdl: name\"foo\" \n dependency\"mir\" version=\"*\"+/ void main() { import mir.combinatorics, std.stdio; writeln([0, 1].permutations); }"
bsource=$(echo -e "$source" | base64 -w0)
[ "$(docker run --rm "$dockerId" "$bsource")" == "[[0, 1], [1, 0]]" ]

source="/++dub.sdl: name\"foo\" \n dependency\"vibe-d\" version=\"*\"+/ void main() { import vibe.d, std.stdio; Json a; a.writeln; }"
bsource=$(echo -e "$source" | base64 -w0)
[ "$(docker run --rm "$dockerId" "$bsource")" == "null" ]

# Test -c
source='void main() { static assert(0); }'
bsource=$(echo $source | base64 -w0)

# Test -vcg-ast
source='void main() { foreach (i; [1, 2]) {} }'
bsource=$(echo $source | base64 -w0)
DOCKER_FLAGS="-vcg-ast" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "__key"

# Check -asm (DMD-only)
if [[ ! $dockerId =~ "ldc" ]] ; then
    source='void main() { int a; }'
    bsource=$(echo $source | base64 -w0)
    DOCKER_FLAGS="-asm" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "_Dmain"
fi

# Check -ouput-ll and -output-s
if [[ $dockerId =~ "ldc" ]] ; then
    source='void main() { int a; }'
    bsource=$(echo $source | base64 -w0)
    DOCKER_FLAGS="-output-ll" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "@ldc.register_dso"
    DOCKER_FLAGS="-output-s" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "ldc.register_dso:"
fi

# Check HTML output
source='///\nvoid main(){}'
bsource=$(echo $source | base64 -w0)
DOCKER_FLAGS="-D" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "<html>"

# Check JSON output
source='///\nvoid main(){}'
bsource=$(echo $source | base64 -w0)
DOCKER_FLAGS="-Xf=-" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q '"file" : "onlineapp.d"'

# Check Har
source="--- test.d\nvoid main(){import std.stdio; __FILE__.writeln;}"
bsource=$(echo -e "$source" | base64 -w0)
docker run --rm $dockerId $bsource | grep -q "test.d"

# Check har with multiple files
source="--- test.d\nvoid main(){import bar; foo();}\n--- bar.d\nvoid foo(){import std.stdio; __FILE__.writeln;}"
bsource=$(echo -e "$source" | base64 -w0)
docker run --rm $dockerId $bsource | grep -q "bar.d"

# Har - minimal runtime
# Only works on dmd-nightly for now
if [[ $1 = *nightly ]] ; then
source="--- object.d\nmodule object;\n--- bar.d\nextern(C) void main(){printf(\"%s\", __MODULE__.ptr);\n}"
bsource=$(echo -e "$source" | base64 -w0)
DOCKER_FLAGS="-conf= -defaultlib=" docker run -e DOCKER_FLAGS --rm $dockerId $bsource 2>&1 | grep -q '`printf` is not defined'
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
