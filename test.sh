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
