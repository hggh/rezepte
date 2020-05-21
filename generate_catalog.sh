#!/bin/sh
#-
# Copyright © 2020
#	mirabilos <m@mirbsd.org>
#
# Provided that these terms and disclaimer and all copyright notices
# are retained or reproduced in an accompanying document, permission
# is granted to deal in this work without restriction, including un‐
# limited rights to use, publicly perform, distribute, sell, modify,
# merge, give away, or sublicence.
#
# This work is provided “AS IS” and WITHOUT WARRANTY of any kind, to
# the utmost extent permitted by applicable law, neither express nor
# implied; without malicious intent or gross negligence. In no event
# may a licensor, author or contributor be held liable for indirect,
# direct, other damage, loss, or other issues arising in any way out
# of dealing in the work, even if advised of the possibility of such
# damage or existence of a defect, except proven that it results out
# of said person’s immediate fault when using the work as intended.

LC_ALL=C; LANGUAGE=C
export LC_ALL
unset LANGUAGE

die() {
	echo >&2 "E: $*"
	exit 1
}

T=$(mktemp -d /tmp/gencat.XXXXXXXXXX) || \
    die 'could not generate temporary directory'

cleanup() {
	cd /
	rm -rf "$T"
	return $1
}
trap 'cleanup $?' EXIT

cd "$(dirname "$0")" || die 'could not cd'
set -e

rm -rf owner tags
mkdir owner tags
rm -f rezepte/index.md

exec 4>"$T/rezepte"
for fn in rezepte/*; do
	test -f "$fn" || continue
	set --
	exec <"$fn"
	fn=${fn##*/}
	name=
	IFS= read -r line || die "not in correct format (too short): $fn"
	case $line in
	(---|'<!--') ;;
	(*) die "not in correct format (1): $fn" ;;
	esac
	IFS= read -r line || die "not in correct format (too short): $fn"
	case $line in
	("owner: "?*) ;;
	(*) die "not in correct format (2): $fn" ;;
	esac
	owner=${line#owner: }
	test -d owner/"$owner" || mkdir owner/"$owner"
	exec 5>>"$T/owner-$owner"
	IFS= read -r line || die "not in correct format (too short): $fn"
	case $line in
	("name: "?*)
		name=${line#name: }
		IFS= read -r line || die "not in correct format (tags?): $fn"
		;;
	esac
	test x"$line" = x"tags:" || die "not in correct format (3): $fn"
	while :; do
		IFS= read -r line || die "not in correct format (aborted): $fn"
		case $line in
		(---|'-->') break ;;
		('- '*) ;;
		(*) die "not in correct format (tag $line): $fn" ;;
		esac
		line=${line#- }
		test -d tags/"$line" || mkdir tags/"$line"
		set -- "$@" "$line"
	done
	sed \
	    -e 's!\.\./!&&!g' \
	    >owner/"$owner"/"$fn"
	line=$(sed 1q <owner/"$owner"/"$fn") || line=
	test -n "$name" || name=$line
	test -n "$name" || name=${fn%.*}
	line="* [$name]($fn)"
	echo "$line" >&4
	echo "$line" >&5
	for tag in "$@"; do
		echo "$line" >>"$T/tags-$tag"
		cp owner/"$owner"/"$fn" tags/"$tag"/
	done
done
exec </dev/null 4>/dev/null 5>/dev/null

doindex() {
	echo "$2"
	echo =====================
	echo
	sort -f <"$1"
}

for line in owner/*; do
	line=${line#*/}
	echo "* [$line]($line/index.md)"
	doindex "$T/owner-$line" "Rezepte von $line" >owner/"$line"/index.md
done >"$T/owner"
doindex "$T/owner" "Rezepte nach Eigner" >owner/index.md

for line in tags/*; do
	line=${line#*/}
	echo "* [$line]($line/index.md)"
	doindex "$T/tags-$line" "Rezepte für $line" >tags/"$line"/index.md
done >"$T/tags"
doindex "$T/tags" "Rezepte nach Kategorie" >tags/index.md

doindex "$T/rezepte" "Alle Rezepte" >rezepte/index.md

echo >&2 "I: all done"
