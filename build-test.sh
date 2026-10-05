#!/usr/bin/env bash
# Build and test the images from .github/workflows/run-test-sh.yml.
# Usage: ./build-test.sh [dmd-nightly|dmd-beta|dmd|ldc-beta|ldc]...
# With no arguments, every image is built and tested, in CI order.

set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
cd "$root"

if [[ ! -f har/harmain.d ]]; then
  git submodule update --init har
fi

dlang_exec_for() {
  case $1 in
    dmd-nightly | dmd-beta | dmd) printf '%s\n' dmd ;;
    ldc-beta | ldc) printf '%s\n' ldmd2 ;;
    *) return 1 ;;
  esac
}

# Same order as the workflow matrix.
default_versions=(dmd-nightly dmd-beta dmd ldc-beta ldc)

if [[ $# -eq 0 ]]; then
  versions=("${default_versions[@]}")
else
  versions=("$@")
fi

for version in "${versions[@]}"; do
  if ! dlang_exec_for "$version" >/dev/null; then
    echo "Unknown image '${version}'." >&2
    echo "Known images: ${default_versions[*]}" >&2
    exit 2
  fi
done

work=
cleanup() {
  if [[ -n $work && -d $work ]]; then
    rm -rf "$work"
  fi
}
trap cleanup EXIT

for version in "${versions[@]}"; do
  dlang_exec=$(dlang_exec_for "$version")
  tag="dlangtour/core-exec:${version}"

  echo "=== Building ${tag} ==="
  docker build \
    --build-arg "DLANG_VERSION=${version}" \
    --build-arg "DLANG_EXEC=${dlang_exec}" \
    --tag "$tag" \
    "$root"

  echo "=== Testing ${tag} ==="
  # test.sh writes command_output.tmp in the working directory.
  work=$(mktemp -d)
  (
    cd "$work"
    bash "${root}/test.sh" "$tag"
  )
  rm -rf "$work"
  work=
done
