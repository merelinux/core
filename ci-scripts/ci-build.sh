#!/bin/bash -e
# shellcheck disable=SC2154,SC1091

. "$CIRCLE_WORKING_DIRECTORY"/.env

for pkg in "${pkgs[@]}"; do
    MEREDIR="$(pwd)/mere-build" ./ci-scripts/buildpkg.sh "$pkg"
    # List built packages
    find mere-build || printf 'No mere-build dir\n'
done
