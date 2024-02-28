#!/bin/bash -e
# shellcheck disable=SC2154,SC1091
bn="$(git rev-parse --abbrev-ref HEAD)"

pkgs=()
case "$bn" in
    main)
    # install pacman-build
    install -d /tmp/pacman
    curl -LO http://pkgs.merelinux.org/core/testing/os/pacman-latest-$(arch).pkg.tar.xz
    tar -C /tmp/pacman -xf pacman-latest-$(arch).pkg.tar.xz 2>/dev/null

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
        -r /tmp/tools --noconfirm pacman-build

    for dir in packages/* ; do
        unset pkgname pkgver pkgrel arch
        printf 'Processing %s\n' "$dir"
        . "${dir}/PKGBUILD"

        if ! printf '%s\0' "${arch[@]}" | grep -Fqxz -- "$(arch)" && \
           ! printf '%s\0' "${arch[@]}" | grep -Fqxz -- "any"; then
            # Doesn't match this architecture, don't build.
            continue
        fi

        for pkg in "${pkgname[@]}"; do
            printf '  Evaluating package %s\n' "$pkg"
            syncver=$(/tmp/pacman/usr/bin/pacman \
                      --config /tmp/pacman/etc/pacman.conf \
                      -r /tmp/tools -Si "$pkg" | \
                      grep -E '^Version' | awk '{print $NF}')
            printf '    syncver:   %s\n' "$syncver"
            printf '    parsedver: %s\n' "${pkgver}-${pkgrel}"
            if [ "$syncver" != "${pkgver}-${pkgrel}" ]; then
                pkgs+=("$dir")
                break
            fi
        done
    done
    ;;
    *)
    for file in $(git diff --name-only main) ; do
        if printf '%s' "$file" | grep -q '^packages/.*/PKGBUILD'; then
            # skip build if package is deleted
            git log --oneline --full-history -1 -p -- "$file" \
                | head | grep -q '^+++ /dev/null' && continue

            # skip build if package is not in this arch
            unset arch
            . "${dir}/PKGBUILD"
            if ! printf '%s\0' "${arch[@]}" | grep -Fqxz -- "$(arch)" && \
               ! printf '%s\0' "${arch[@]}" | grep -Fqxz -- "any"; then
               # Doesn't match this architecture, don't build.
               continue
            fi

            pkgs+=("${file%/*}")
        fi
    done
    ;;
esac

printf 'pkgs is: %s\n' "${pkgs[@]}"
mapfile -t unique_pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
printf 'unique_pkgs is: %s\n' "${unique_pkgs[@]}"

install -d "$CIRCLE_WORKING_DIRECTORY"
cat >"$CIRCLE_WORKING_DIRECTORY"/.env <<EOF
bn='$bn'
pkgs=(${unique_pkgs[@]})
EOF

printf '%s\n' "$MERE_SIGNING_KEY" | base64 -d >"$CIRCLE_WORKING_DIRECTORY"/mere.key
