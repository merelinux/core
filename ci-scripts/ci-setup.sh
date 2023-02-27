#!/bin/bash -e
# shellcheck disable=SC2154,SC1091
bn="$(git rev-parse --abbrev-ref HEAD)"

pkgs=()
if [ "$bn" = 'main' ] ; then
    pacman -Sy
    for dir in packages/* ; do
        . "${dir}/PKGBUILD"
        for pkg in "${pkgname[@]}"; do
            syncver=$(pacman -Si "$pkg" | grep -E '^Version' | awk '{print $NF}')
            if [ "$syncver" != "${pkgver}-${pkgrel}" ]; then
                pkgs+=("${dir%/*}")
                break
            fi
        done
    done
else
    for file in $(git diff --name-only main) ; do
        if printf '%s' "$file" | grep -q '^packages/.*/PKGBUILD'; then
            # skip build if package is deleted
            git log --oneline --full-history -1 -p -- "${unique_pkgs[0]}/PKGBUILD" \
                | head | grep -q '^+++ /dev/null' && continue
            pkgs+=("${file%/*}")
        fi
    done
fi

printf 'pkgs is: %s\n' "${pkgs[@]}"
mapfile -t unique_pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
printf 'unique_pkgs is: %s\n' "${unique_pkgs[@]}"

install -d "$CIRCLE_WORKING_DIRECTORY"
cat >"$CIRCLE_WORKING_DIRECTORY"/.env <<EOF
bn='$bn'
pkgs=(${unique_pkgs[@]})
EOF

printf '%s\n' "$MERE_SIGNING_KEY" | base64 -d >"$CIRCLE_WORKING_DIRECTORY"/mere.key

