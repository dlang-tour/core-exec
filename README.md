# Docker container for running rdmd

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
    > docker run --rm dlangtour/core-exec:dmd-nightly $bsource

    Hello World, Digital Mars D (2074)

    > bsource=$(echo 'void main() { import std.stdio; writefln("Hello World, %s (%s)",  __VENDOR__, __VERSION__); }' | base64 -w0)
    > docker run --rm dlangtour/core-exec:ldc $bsource

    Hello World, LDC (2072)

### Stdin

    $ bsource=$(echo 'void main() { import std.algorithm, std.stdio; stdin.byLine.each!writeln; }' | base64 -w0)
    $ bstdin=$(printf 'Venus\nParis\nMontreal' | base64 -w0)
    $ docker run --rm dlangtour/core-exec:dmd $bsource $bstdin
    Venus
    Paris
    Montreal

### Custom compiler arguments

    $ bsource=$(echo 'void main() { import std.stdio; version(Foo) writeln("Hello World"); }' | base64 -w0)
    $ DOCKER_FLAGS="-version=Foo" docker run -e DOCKER_FLAGS --rm dlangtour/core-exec:dmd $bsource
    Hello World

### Colored output

    $ bsource=$(echo 'void main() { import foo; version(Foo) writeln("Hello World"); }' | base64 -w0)
    $ DOCKER_COLOR="on" docker run -e DOCKER_COLOR --rm dlangtour/core-exec:dmd $bsource

![image](https://user-images.githubusercontent.com/4370550/28495813-0f497240-6f5b-11e7-9108-18e5ad6366c5.png)

## Docker image

The docker image gets built after every push to `master` and pushed to [DockerHub](https://hub.docker.com/r/dlang-tour/core-exec/).
They are updated daily.
The following images are available:

- `dlangtour/core-exec:dmd-nightly`
- `dlangtour/core-exec:dmd-beta`
- `dlangtour/core-exec:dmd`
- `dlangtour/core-exec:ldc-beta`
- `dlangtour/core-exec:ldc`
- `dlangtour/core-exec:gdc`

## License

Boost license.
