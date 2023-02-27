#!/bin/bash -e
pkgs=()
bn="$(git rev-parse --abbrev-ref HEAD)"
compare='main'
[ "$bn" = 'main' ] || compare='HEAD~1'
for file in $(git diff --name-only "$compare") ; do
    if printf '%s' "$file" | grep -q '^packages/.*/PKGBUILD'; then
        pkgs+=("${file%/*}")
    fi
done
printf 'pkgs is: %s\n' "${pkgs[@]}"
mapfile -t unique_pkgs < <(printf '%s\n' "${pkgs[@]}" | sort -u)
if [ "${#unique_pkgs[@]}" -gt 1 ] ; then
    printf 'More than one package directory has been changed in this commit.\n'
    exit 1
fi
printf 'unique_pkgs is: %s\n' "${unique_pkgs[@]}"

is_deleted='false'
if git log --oneline --full-history -1 -p -- "${unique_pkgs[0]}/PKGBUILD" \
    | head | grep -q '^+++ /dev/null'; then
    is_deleted='true'
fi

install -d "$CIRCLE_WORKING_DIRECTORY"
cat >"$CIRCLE_WORKING_DIRECTORY"/.env <<EOF
pkg='${unique_pkgs[0]}'
is_deleted=$is_deleted
EOF

printf '%s\n' "$MERE_SIGNING_KEY" | base64 -d >"$CIRCLE_WORKING_DIRECTORY"/mere.key

curl -fsSL https://tailscale.com/install.sh | sudo sh
sudo tailscale up --authkey="$TS_KEY" \
    --hostname="mereci-${CIRCLE_BUILD_NUM}-${CIRCLE_NODE_TOTAL}-${CIRCLE_NODE_INDEX}"

