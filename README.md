# Docker container for running rdmd

This docker image provides the current version of the
[rdmd](https://dlang.org) compiler of the D programming language.
The container takes source code encoded as **Base64** on the command line and
decodes it internally and passes it to `rdmd`. The compiler
tries to compile the source and, if successful, outputs
the program's output. Compiler errors will also be output,
to stderr.

This container is used in the [dlang-tour](https://github.com/stonemaster/dlang-tour)
to support online compilation of user code in a safe sandbox.

## Usage

Given a source code:

	$ source='void main() { import std.stdio; writeln("Hello World"); }

Convert it to Base64:

	$ bsource=$(echo $source | base64 -w0)

Run the docker container passing the base64 source as
command line parameter:

	$ docker run --rm stonemaster/dlang-tour-rdmd $bsource
	Hello World

## Docker image

The docker image gets built after every push to `master` and pushed to [DockerHub](https://hub.docker.com/r/stonemaster/dlang-tour-rdmd/).

## License

Boost license.
