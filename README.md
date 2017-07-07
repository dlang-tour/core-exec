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
