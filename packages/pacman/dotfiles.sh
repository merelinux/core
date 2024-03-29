#!/bin/bash
#
#   dotfiles.sh - check for dotfiles in the package root
#
#   Copyright (c) 2016-2021 Pacman Development Team <pacman-dev@archlinux.org>
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

[[ -n "$LIBMAKEPKG_LINT_PACKAGE_DOTFILES_SH" ]] && return
LIBMAKEPKG_LINT_PACKAGE_DOTFILES_SH=1

LIBRARY=${LIBRARY:-'/usr/share/makepkg'}

# shellcheck disable=SC1091
source "$LIBRARY/util/message.sh"

lint_package_functions+=('check_dotfiles')

check_dotfiles() {
	local ret=0
    # shellcheck disable=SC2154
    files=$(find "$pkgdir" -mindepth 1 -maxdepth 1 -name '.*')
    for f in $files; do
		[[ ${f##*/} == . || ${f##*/} == .. ]] && continue
		error "$(gettext "Dotfile found in package root '%s'")" "$f"
		ret=1
	done
	return $ret
}
