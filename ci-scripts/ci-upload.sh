#!/bin/bash -e
bn="$(git rev-parse --abbrev-ref HEAD)"
if [ "$bn" = 'main' ] ; then

    # install pacman-build
    install -d /tmp/pacman
    curl -LO http://pkgs.merelinux.org/core/pacman-latest-x86_64.pkg.tar.xz
    tar -C /tmp/pacman -xf pacman-latest-x86_64.pkg.tar.xz 2>/dev/null

    cat >/tmp/pacman/etc/pacman.conf <<- "EOF"
	[options]
	HoldPkg      = pacman busybox
	Architecture = auto
	ParallelDownloads = 3
	SigLevel = Never

	[core]
	Server = https://pkgs.merelinux.org/core/testing/os/$arch
	EOF

    install -d /tmp/tools/var/lib/pacman
    sudo /tmp/pacman/usr/bin/pacman -Sy --config /tmp/pacman/etc/pacman.conf \
        -r /tmp/tools --noconfirm pacman-build curl jq
    export PATH="/tmp/tools/bin:/tmp/tools/usr/bin:$PATH"

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
