#!/bin/bash
#
#   dependencies.sh - Warn about missing library dependencies
#
#   Copyright (c) 2017 Jeremy Huntwork <jhuntwork@lightcubesolutions.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# shellcheck disable=SC2154

[ -n "$LIBMAKEPKG_LINT_PACKAGE_DEPENDENCIES_SH" ] && return
LIBMAKEPKG_LINT_PACKAGE_DEPENDENCIES_SH=1

LIBRARY=${LIBRARY:-'/usr/share/makepkg'}

# shellcheck disable=SC1091
source "${LIBRARY}/util/message.sh"

lint_package_functions+=('warn_dependencies')

list_file_dependencies() {
    if [ -z "$1" ] || [ ! -f "$1" ] ; then
        return 1
    fi
    TMP=$(mktemp)
    local deps=''
    local badlinks=0

    local lddout
    lddout=$(ldd "$1" 2>"$TMP")
    # shellcheck disable=SC2181
    if [ $? -ne 0 ] || grep -q 'No such file' "$TMP" || \
            grep -q 'symbol not found' "$TMP" ; then
        badlinks=1
    fi

    local IFS=$'\n'
    for i in $lddout ; do
        local dep
        if printf '%s\n' "$i" | grep -q =\> ; then
            dep=$(printf '%s\n' "$i" | awk '{print $3}' | awk -F/ '{print $NF}')
        else
            dep=$(printf '%s\n' "$i" | awk '{print $1}' | awk -F/ '{print $NF}')
        fi
        [ -z "$dep" ] && continue
        case "$dep" in
            $(pwd)*) ;;
            ldd|libc.so) deps=$(printf '%s\n' "ld-musl-$(arch).so.1" "$deps") ;;
            *)   deps=$(printf '%s\n' "$dep" "$deps") ;;
        esac
    done
    printf '%s\n' "$deps"
    rm "$TMP"
    [ $badlinks -eq 0 ] || return 1
}

collect_all_lib_dependencies() {
    if [ -z "$1" ] || [ ! -d "$1" ] ; then
        printf 'Must specify a directory\n'
        return 1
    fi

    alldeps=$(mktemp)
    local badlinks=0

    find "$1" -not -type d | while read -r file; do
        local deps=''
        ft=$(file -b "$file")
        case "$ft" in
            *ELF*dynamic*)
                deps=$(LD_LIBRARY_PATH="${1}/lib" list_file_dependencies "$file")
                printf '%s\n' "$deps" >>"$alldeps"
                ;;
            *)
                ;;
        esac
    done
    sort -u < "$alldeps"
    rm "$alldeps"
}

warn_dependencies() {
    local badlinks=0
    local pkg_deps
    pkg_deps=$(collect_all_lib_dependencies "$pkgdir")
    local not_found=()
    # shellcheck disable=SC2181
    [ $? -ne 0 ] && badlinks=1
    if [ $badlinks -eq 1 ] ; then
	    error 'Package contains libraries with unresolvable symbols'
        return 1
    fi
    if [ -n "$depends" ] ; then
        msg2 "$(gettext "Defined dependency: %s")" "${depends[@]}"
    fi
    for lib in $pkg_deps; do
        local found=0
        for dep in "${depends[@]}" ; do
            if [ "$dep" = "$lib" ]; then
                found=1
                break
            fi
        done
        if [ $found -eq 0 ] ; then
            for p in "${provides[@]}"; do
                if [ "$p" = "$lib" ]; then
                    found=1
                    break
                fi
            done
        fi
        if [ $found -eq 0 ] ; then
            not_found+=("$lib")
        fi
    done
    if [ ${#not_found[@]} -gt 0 ] ; then
        error "$(gettext "Missing dependencies:")"
        printf '        %s\n' "${not_found[@]}" | tee "/tmp/missingdeps.${pkgname}"
        return 2
    fi
}
