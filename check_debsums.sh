#!/bin/sh
#
# Copyright (C) 2009 Cyril Bouthors <cyril@bouthors.org>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# 2013-05-08 Copied this script from https://github.com/cyril-bouthors/nagios-plugins-cyb/blob/master/plugins/check_debsums
#            and modified to retry a few times, since we expect to be doing these for several packages.
#            Also changed the exit code for a failed lockfile placement to 3, UNKNOWN.
#            -- Tim Stoop <tim@kumina.nl>

set -e

pkgs=$*

if [ -z "$pkgs" ]
then
    echo $0: Too few argument >&2
    echo $0 PKG [PKG [PKG]] >&2
    exit 1
fi

lockfile=/var/lock/nagios-check-debsums

dotlockfile -r 5 -p $lockfile || exit 3

if ! debsums -s $pkgs 2>/dev/null
then
    debsums -s $pkgs 2>&1 | tr "\n" ' '
    exit 2
fi

dotlockfile -u $lockfile

echo OK
exit 0
