#!/bin/bash -e
# shellcheck disable=SC2154,SC1091
bn="$(git rev-parse --abbrev-ref HEAD)"

pkgs=()
case "$bn" in
    main)
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
        -r /tmp/tools --noconfirm pacman-build

    for dir in packages/* ; do
        unset pkgname pkgver pkgrel
        . "${dir}/PKGBUILD"
        printf 'Processing %s\n' "$dir"
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

case "$bn" in
    *-parallel|main)
        curl -fsSL https://tailscale.com/install.sh | sudo sh
        sudo tailscale up --authkey="$TS_KEY" \
            --hostname="mereci-${CIRCLE_BUILD_NUM}-${CIRCLE_NODE_TOTAL}-${CIRCLE_NODE_INDEX}"
        ;;
esac

printf '%s\n' "$MERE_SIGNING_KEY" | base64 -d >"$CIRCLE_WORKING_DIRECTORY"/mere.key

