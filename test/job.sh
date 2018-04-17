#!/bin/sh -eux

REL="$1"
IDU="$2"
IDG="$3"

# Setup (deps from docker.io:erlang:alpine)
apk update && apk upgrade
apk add curl ca-certificates \
        dpkg-dev dpkg \
        gcc g++ libc-dev linux-headers make autoconf ncurses-dev tar \
        openssl-dev unixodbc-dev lksctp-tools-dev \
        lksctp-tools \
        libxslt git
say() {
    printf '\n\e[1;3m%s\e[0m\n' "$*"
}

# Fetch reference build of docs
odir=/ref/docs-$REL
if [ ! -d "$odir" ]; then
    curl -#fSLo "$odir".tar.bz2 https://erldocs.com/archives/docs-"$REL".tar.bz2
    tar xaf "$odir".tar.bz2 -C /ref
    ( cd "$odir"
      git init
      git add -Af .
      git config --global user.email bip@bap.ulula
      git config --global user.name rldcs
      git commit -m ref
    )
fi


# Fetch + build + install + build docs
gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
# This makes build fail with: "cannot generate otp_ded.mk" for the wrong arch...
# export KERL_CONFIGURE_OPTIONS="--build=$gnuArch"
export KERL_BASE_DIR=/rel
export KERL_BUILD_BACKEND=tarball  # git | tarball
export KERL_BUILD_DOCS=yes
MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)"; export MAKEFLAGS
say Building on "$gnuArch" with "$MAKEFLAGS"
if ! [ -f $KERL_BASE_DIR/otp_releases ]; then
    kerl update releases
fi
if ! grep -Fo "$REL" $KERL_BASE_DIR/otp_releases >/dev/null; then
    say Tag "$REL" is unknown to GitHub!
    exit 1
fi

idir=$KERL_BASE_DIR/builds/$REL/otp_src_$REL
if ! [ -d "$idir" ]; then
    say Commencing build of "$REL" and docs
    if kerl build "$REL" "$REL"; then
        say Built "$REL" and docs
    else
        say Could not make "$REL" and docs
        exit 2
    fi
fi

release_local_dir=$KERL_BASE_DIR/$REL
if ! [ -d "$release_local_dir" ]; then
    say Installing "$REL" into "$release_local_dir"
    if ! kerl install "$REL" "$release_local_dir"; then
        say Could not install "$REL" in "$release_local_dir" Try rebuilding.
        exit 3
    fi
fi

say Using erl from "$release_local_dir"
set +o nounset
. "$release_local_dir"/activate

if ! [ -d /app/rebar3 ]; then
    git clone --depth=1 https://github.com/erlang/rebar3.git /app/rebar3
    cd /app/rebar3
    ./bootstrap
    ./rebar3 local install
fi
export PATH="$PATH":$HOME/.cache/rebar3/bin
rebar3 --version

erldocs=/app/erldocs/_build/default/bin/erldocs
if ! [ -x "$erldocs" ]; then
    say Building erldocs
    ( cd /app/erldocs
      rebar3 escriptize
    )
    chown -R "$IDU":"$IDG" /app/erldocs
fi
[ -x "$erldocs" ]

rm -rf "${odir:?}"/* "${odir:?}"/.xml >/dev/null
"$erldocs" -o "$odir" "$idir"/lib/* "$idir"/erts*
chown -R "$IDU":"$IDG" /ref /rel
cd "$odir"
git status --porcelain
[ '0' = "$(git status --porcelain | wc -l)" ]
