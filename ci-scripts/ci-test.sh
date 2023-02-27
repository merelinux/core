#!/bin/bash -e
# shellcheck disable=SC2154,SC1091
. "$CIRCLE_WORKING_DIRECTORY"/.env

for pkg in "${pkgs[@]}"; do
    if [ -f "$pkg/PKGTEST" ]; then
        cd "$pkg"
        sh PKGTEST
    fi
done
