#!/bin/bash -e
# shellcheck disable=SC1091
. "$CIRCLE_WORKING_DIRECTORY"/.env
if [ "$bn" = 'main' ] ; then
    # Sync down existing files in the testing repo
    printf 'Syncing down core/testing repo\n'
    install -d testing
    rsync -rlptv -e 'ssh -p 50220' \
        "pkgsync@pkgs.merelinux.org::pkgs/core/testing/os/$(arch)/" testing/

    # Copy over the staging files to testing
    printf '%s\n' "$MERE_SIGNING_KEY" | base64 -d >"$CIRCLE_WORKING_DIRECTORY"/mere.key
    find mere-build -name "*.pkg*" -not -name "*.sig" | while read -r file ; do
        mv -v "$file" testing/
        [ -f "${file}.sig" ] && mv -v "${file}.sig" testing/
        LIBRARY=/tmp/tools/usr/share/makepkg repo-add \
            --sign --key "${CIRCLE_WORKING_DIRECTORY}/mere.key" \
            -R testing/core.db.tar.gz "testing/${file##*/}"
    done
    find mere-build -name "*.src.tar.xz" | while read -r file; do
        bn=${file##*/}
        noext=${bn%.src.tar.xz*}
        norel=${noext%-*}
        nover=${norel%-*}
        install -d "src/${nover}"
        mv -v "$file" "src/${nover}/"

        printf 'Syncing up source packages\n'
        rsync -rlptv --delete-after -e 'ssh -p 50220' \
            "src/${nover}/" "pkgsync@pkgs.merelinux.org::pkgs/src/${nover}/"
    done

    # Upload
    printf 'Syncing up testing repo\n'
    rsync -rlptv --delete-after -e 'ssh -p 50220' \
        testing/ "pkgsync@pkgs.merelinux.org::pkgs/core/testing/os/$(arch)/"

fi
