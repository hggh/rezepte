#!/bin/sh
#-
# Copyright © 2020, 2023
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

htmlesc() {
	tr -d '[--]' | tr '\n' '' | { cat; echo; } | sed \
	    -e 's/[	 ]*$//g' \
	    -e 's/[&]/\&amp;/g' \
	    -e 's/[]/\&#10;/g' \
	    -e 's/["]/\&quot;/g'
}

# for now (more escaping will be added as needed)
mdlink() {
	echo "[$1]$(echo "($2)" | sed \
	    -e 's/%/%25/g' \
	    -e 's/ /%20/g' \
	    )"
}

exec 4>"$T/rezepte"
for fn in rezepte/*; do
	test -f "$fn" || continue
	set --
	exec <"$fn"
	fn=${fn##*/}
	bn=${fn%.*}
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
		case $line in
		(*[-/:-@[-\`{-]*)
			die "control or otherwise weird character in tag '$line' in $fn"
			;;
		esac
		test -d tags/"$line" || mkdir tags/"$line"
		set -- "$@" "$line"
	done
	sed \
	    -e 's!\.\./!&&!g' \
	    >owner/"$owner"/"$fn"
	line=$(sed 1q <owner/"$owner"/"$fn") || line=
	test -n "$name" || name=$line
	test -n "$name" || name=$bn
	line="* $(mdlink "$name" "$fn")"
	sep='  '
	for pic in pics/"$bn".*; do
		test -e "$pic" || continue
		case $pic in
		(*.lbl)
			continue
			;;
		(pics/"$bn".*.*)
			pictag=${pic#pics/"$bn".}
			pictag="$bn (${pictag%.*})"
			;;
		(*)
			pictag=$bn
			;;
		esac
		pictag=$(echo "X$pictag" | htmlesc); pictag=${pictag#X}
		if test -s "${pic%.*}.lbl"; then
			piclbl=$(expand <"${pic%.*}.lbl" | htmlesc)
			picalt="$pictag: $piclbl"
			pictit="$pictag:&#10;$piclbl"
			picalt=$(echo "X$pictit" | sed 's/[&][#]10;/ /g')
			picalt=${picalt#X}
		else
			picalt=$pictag
			pictit=$pictag
		fi
		case $pic in
		(pics/*[!A-Za-z0-9_.~-]*)
			pictag=../../pics/$(echo "$pic" | perl -0777 -pe '
				s!^pics/!!;
				chop;
				s/([^A-Za-z0-9_.~-])/sprintf "%%%02X", ord($1)/eg;
			    ')
			;;
		(*)
			pictag=../../$pic
			;;
		esac
		# funnily enough, this is the correct way to do it in GFM…
		pictag="<img src=\"$pictag\" width=\"30%\""
		pictag="$pictag alt=\"$picalt\" title=\"$pictit\" />"
		line=$line$sep$pictag
		sep='  '
	done
	echo "$line" | sed 's!\(<img src="\)\.\./\(\.\./pics/\)!\1\2!g' >&4
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
	sort -f <"$1" | tr '' '\n'
}

for line in owner/*; do
	line=${line#*/}
	echo "* $(mdlink "$line" "$line/index.md")"
	doindex "$T/owner-$line" "Rezepte von $line" >owner/"$line"/index.md
done >"$T/owner"
doindex "$T/owner" "Rezepte nach Eigner" >owner/index.md

for line in tags/*; do
	line=${line#*/}
	echo "* $(mdlink "$line" "$line/index.md")"
	doindex "$T/tags-$line" "Rezepte für $line" >tags/"$line"/index.md
done >"$T/tags"
doindex "$T/tags" "Rezepte nach Kategorie" >tags/index.md

doindex "$T/rezepte" "Alle Rezepte" >rezepte/index.md

echo >&2 "I: all done"
