# Docker container for running rdmd

[![master](https://github.com/dlang-tour/core-exec/actions/workflows/run-test-sh.yml/badge.svg)](https://github.com/dlang-tour/core-exec/actions/workflows/run-test-sh.yml)

This docker image provides the current version of the
[rdmd](https://dlang.org) compiler of the D programming language.
The container takes source code encoded as **Base64** on the command line and
decodes it internally and passes it to `rdmd`. The compiler
tries to compile the source and, if successful, outputs
the program's output. Compiler errors will also be output,
to stderr.

This container is used in the [dlang-tour](https://github.com/dlang-tour/core)
to support online compilation of user code in a safe sandbox.

## Usage

Run the docker container passing the base64 source as
command line parameter:

    > bsource=$(echo 'void main() { import std.stdio; writefln("Hello World, %s (%s)",  __VENDOR__, __VERSION__); }' | base64 -w0)
    > docker run --rm ghcr.io/dlang-tour/core-exec:dmd-nightly $bsource

    Hello World, Digital Mars D (2074)

    > bsource=$(echo 'void main() { import std.stdio; writefln("Hello World, %s (%s)",  __VENDOR__, __VERSION__); }' | base64 -w0)
    > docker run --rm ghcr.io/dlang-tour/core-exec:ldc $bsource

    Hello World, LDC (2072)

### Stdin

    $ bsource=$(echo 'void main() { import std.algorithm, std.stdio; stdin.byLine.each!writeln; }' | base64 -w0)
    $ bstdin=$(printf 'Venus\nParis\nMontreal' | base64 -w0)
    $ docker run --rm ghcr.io/dlang-tour/core-exec:dmd $bsource $bstdin
    Venus
    Paris
    Montreal

### Custom compiler arguments

    $ bsource=$(echo 'void main() { import std.stdio; version(Foo) writeln("Hello World"); }' | base64 -w0)
    $ DOCKER_FLAGS="-version=Foo" docker run -e DOCKER_FLAGS --rm ghcr.io/dlang-tour/core-exec:dmd $bsource
    Hello World

### Colored output

    $ bsource=$(echo 'void main() { import foo; version(Foo) writeln("Hello World"); }' | base64 -w0)
    $ DOCKER_COLOR="on" docker run -e DOCKER_COLOR --rm ghcr.io/dlang-tour/core-exec:dmd $bsource

![image](https://user-images.githubusercontent.com/4370550/28495813-0f497240-6f5b-11e7-9108-18e5ad6366c5.png)

## Local build

`./build-test.sh` builds the CI images and runs `./test.sh` on each one.
Pass image names to build a subset:

    ./build-test.sh dmd ldc

## Docker image

The docker image gets built after every push to `master` and pushed to [GHCR](https://github.com/dlang-tour/core-exec/pkgs/container/core-exec).
They are updated daily.

Pull a tag:

    $ docker pull ghcr.io/dlang-tour/core-exec:dmd

If the package is private, log in first with a GitHub personal access
token that has the `read:packages` scope. The username is your GitHub
username, and the password is the token:

    $ docker login ghcr.io
    $ docker pull ghcr.io/dlang-tour/core-exec:dmd

The following images are available:

- `ghcr.io/dlang-tour/core-exec:dmd-nightly`
- `ghcr.io/dlang-tour/core-exec:dmd-beta`
- `ghcr.io/dlang-tour/core-exec:dmd`
- `ghcr.io/dlang-tour/core-exec:ldc-beta`
- `ghcr.io/dlang-tour/core-exec:ldc`
- `ghcr.io/dlang-tour/core-exec:gdc`

## License

Boost license.
