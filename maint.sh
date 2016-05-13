#!/bin/bash

# Generate erldocs for Erlang/OTP's maint branch.

[[ $# -ne 2 ]] && echo "Usage: $0  ‹erldocs.com site Git folder› ‹path to cloned repo›" && exit 1
site_root="${1%%/}"
[[ ! -d "$site_root"/.git ]] && echo "$site_root is not a Git repo!" && exit 1
idir="${2%%/}" # Remove trailing slash if exists
[[ ! -d "$idir"/.git ]] && echo "$idir is not a Git repo!" && exit 1
[[ ! -x "$idir"/otp_build ]] && echo "$idir is not the OTP repo!" && exit 1

erldocs='./erldocs'
[[ ! -x "$erldocs" ]] && [[ ! -L "$erldocs" ]] && \
    echo "$erldocs executable not found!" && exit 1

release="maint"
odir="docs-$release"

site="$site_root/$release"
[[ ! -d "$site" ]] && echo "$site not found" && exit 1
archive="$site_root/archives/${odir}.tar.bz2"


mkdir -p  "$odir"
rm    -rf "$odir"/*

cd "$idir"
echo "Commencing pull & build of $release branch" \
    && git checkout -- . \
    && git checkout maint \
    && git pull origin maint \
    && MAKEFLAGS=-j6 ./otp_build setup -a \
    && MAKEFLAGS=-j6 make docs
if [[ $? -ne 0 ]]; then
    echo "Could not make $release"
    cd -
    exit 2
fi
cd -

"$erldocs"          \
    -o "$odir"      \
    "$idir"/lib/*   \
    "$idir"/erts*   \
    | tee _"$release"
[[ $? -ne 0 ]] && exit 3

rm  -rf "$odir"/.xml
tar jcf "$odir".tar.bz2 "$odir"

rm -rf "$site"
mv -v  "$odir" "$site"
mv -v  "$odir".tar.bz2 "$archive"
mv -v  _"$release" "$site"/log-"$release".txt

modifs=$(cd "$site_root" && git status --porcelain | wc -l)
if [[ "$modifs" -eq 2 ]] ; then
    echo "No interesting changes to push."
    cd "$site_root" && git checkout gh-pages -- .
    date
    exit 0
fi
cd "$site_root" \
    && git add "$release" \
    && git add  archives/ \
    && git commit -m "Update OTP's $release branch" \
    && git pull origin gh-pages \
    && git push origin gh-pages
cd -
date
