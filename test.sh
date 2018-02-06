#!/bin/bash

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

source="/++dub.sdl: name\"foo\" \n dependency\"mir\" version=\"~>1.1.1\"+/ void main() { import mir.combinatorics, std.stdio; writeln([0, 1].permutations); }"
bsource=$(echo -e "$source" | base64 -w0)
[ "$(docker run --rm "$dockerId" "$bsource")" == "[[0, 1], [1, 0]]" ]

source="/++dub.sdl: name\"foo\" \n dependency\"vibe-d\" version=\"~>0.8.0\"+/ void main() { import vibe.d, std.stdio; Json a; a.writeln; }"
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
    DOCKER_FLAGS="-output-ll" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "call void @ldc.register_dso"
    DOCKER_FLAGS="-output-s" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "callq\s*ldc.register_dso"
fi

# Check HTML output
source='///\nvoid main(){}'
bsource=$(echo $source | base64 -w0)
DOCKER_FLAGS="-D" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q "<html>"

# Check JSON output

source='///\nvoid main(){}'
bsource=$(echo $source | base64 -w0)
DOCKER_FLAGS="-Xf=-" docker run -e DOCKER_FLAGS --rm $dockerId $bsource | grep -q '"file" : "onlineapp.d"'
