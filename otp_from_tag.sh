#!/bin/bash

# Generate erldocs for a given Erlang/OTP Git tag.

[[ $# -ne 2 ]] && echo "Usage: $0  ‹erldocs.com site Git folder› ‹OTP Git tag›" && exit 1
site_root="${1%%/}"
[[ ! -d "$site_root"/.git ]] && echo "$site_root is not a Git repo!" && exit 1

release="$2"
[[ -z "$release" ]] && echo "Tag is an empty string!" && exit 1
[[ "$release" == */* ]] && echo "Tag '$release' cannot contain slashes" && exit 1


erldocs="${ERLDOCS:-./erldocs}"
[[ ! -x "$erldocs" ]] && [[ ! -L "$erldocs" ]] && \
    echo "$erldocs executable not found!" && exit 1

kerl="${KERL:-kerl}"
"$kerl" status >/dev/null
[[ $? -ne 0 ]] && echo "$kerl executable not found!" && exit 1


KERL_BUILD_BACKEND=git "$kerl" update releases || exit 2
grep -Fo "$release" $HOME/.kerl/otp_releases >/dev/null
[[ $? -ne 0 ]] && echo "Tag '$release' is unknown to GitHub!" && exit 1


idir=$HOME/.kerl/builds/"$release"/otp_src_"$release"
if [[ ! -d "$idir" ]]; then
    KERL_BUILD_BACKEND=git "$kerl" build "$release" "$release"
fi

if [[ ! -f "$idir"/lib/xmerl/doc/src/xmerl.xml ]]; then
    cd "$idir"
    echo "Commencing build of $release's docs" \
        && MAKEFLAGS=-j6 ./otp_build setup -a \
        && MAKEFLAGS=-j6 make docs
    if [[ $? -ne 0 ]]; then
        echo "Could not make $release"
        cd -
        exit 2
    fi
    cd -
fi


odir="docs-$release"

mkdir -p  "$odir"
rm    -rf "./$odir"/*

logfile=_"$release"
"$erldocs"          \
    -o "$odir"      \
    "$idir"/lib/*   \
    "$idir"/erts*   \
    | tee "$logfile"
[[ $? -ne 0 ]] && exit 3

rm  -rf "$odir"/.xml
tar jcf "$odir".tar.bz2 "$odir"

site_cat="$site_root/$release"
rm -rf "$site_cat"
mv -v  "$odir" "$site_cat"
mv -v  "$odir".tar.bz2 "$site_root/archives/${odir}.tar.bz2"
mv -v  "$logfile" "$site_cat"/log-"$release".txt

modifs=$(cd "$site_root" && git status --porcelain -- "$release"/ | wc -l)
echo ."$modifs".
if [[ "$modifs" -le 1 ]] ; then
    echo "No interesting changes to push."
    #cd "$site_root" && git checkout gh-pages -- .
    date
    exit 0
fi
cd "$site_root" \
    && git add -A "$release" \
    && git add archives/"${odir}".tar.bz2 \
    && git commit -m "Built OTP docs from tag $release" \
    && git pull origin gh-pages \
    && git push origin gh-pages
cd -
date
