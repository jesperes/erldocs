#!/bin/bash -eu

[[ $# -ne 1 ]] && echo "Usage: $0  <kerl OTP release>" && exit 2
rel=$1
rel_path=test/otp_rel
ref_path=test/otp_ref

erldocs=_build/default/bin/erldocs
[[ -x $erldocs ]] || exit 3

kerl_path="$(which kerl)"
kerl_bin=/usr/local/bin/kerl

# cat <<EOF
# #!/bin/sh -eux

alpine_cache=/tmp/erldocs_apk_alpine_cache
mkdir -p $rel_path $ref_path $alpine_cache
docker run --rm --interactive \
       --volume $alpine_cache:/var/cache/apk:rw \
       --volume $kerl_path:$kerl_bin:ro \
       --volume "$PWD"/$erldocs:/app/erldocs:ro \
       --volume "$PWD"/$rel_path:/rel:rw \
       --volume "$PWD"/$ref_path:/ref:rw \
       alpine:3.7 \
       /bin/sh -eux -s <<EOF
#!/bin/sh

# Setup (deps from docker.io:erlang:alpine)
apk update && apk upgrade
apk add curl ca-certificates \
        dpkg-dev dpkg \
        gcc g++ libc-dev linux-headers make autoconf ncurses-dev tar \
        openssl-dev unixodbc-dev lksctp-tools-dev \
        lksctp-tools \
        libxslt git
say() {
    printf '\n\e[1;3m%s\e[0m\n' "\$*"
}

# Fetch reference build of docs
odir=/ref/docs-$rel
if [[ ! -d \$odir ]]; then
    curl -#fSLo \$odir.tar.bz2 https://erldocs.com/archives/docs-$rel.tar.bz2
    tar xaf \$odir.tar.bz2 -C /ref
    ( cd \$odir
      git init
      git add -Af .
      git config --global user.email bip@bap.ulula
      git config --global user.name rldcs
      git commit -m ref
    )
fi


# Fetch + build + install + build docs
gnuArch="\$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
# This makes build fail with: "cannot generate otp_ded.mk" for the wrong arch...
# export KERL_CONFIGURE_OPTIONS="--build=\$gnuArch"
export KERL_BASE_DIR=/rel
export KERL_BUILD_BACKEND=git  # git | tarball
export KERL_BUILD_DOCS=yes
export MAKEFLAGS="-j\$(getconf _NPROCESSORS_ONLN)"
say Building on \$gnuArch with \$MAKEFLAGS
if ! [[ -f \$KERL_BASE_DIR/otp_releases ]]; then
    kerl update releases
fi
if ! grep -Fo '$rel' \$KERL_BASE_DIR/otp_releases >/dev/null; then
    say Tag '$rel' is unknown to GitHub!
    exit 1
fi

idir=\$KERL_BASE_DIR/builds/$rel/otp_src_$rel
if [[ ! -d \$idir ]]; then
    say Commencing build of $rel and docs
    if kerl build $rel $rel; then
        say Built $rel and docs
    else
        say Could not make $rel and docs
        exit 2
    fi
fi

release_local_dir=\$KERL_BASE_DIR/$rel
if [[ ! -d \$release_local_dir ]]; then
    say Installing $rel into \$release_local_dir
    if ! kerl install $rel \$release_local_dir; then
        say Could not install $rel in \$release_local_dir Try rebuilding.
        exit 3
    fi
fi
chown -R $(id -u):$(id -g) /rel
say Using erl at "\$(which erl)"
set +eux  # activate is unclean
. \$release_local_dir/activate
set -eux


# Run erldocs
( cd \$odir
for f in * .*; do
    if [[ "\$f" = .git ]] || [[ "\$f" = . ]] || [[ "\$f" = .. ]]; then
        continue
    fi
    rm -rf "\$f"
done
)
say Running erldocs...
if /app/erldocs -o \$odir \$idir/lib/* \$idir/erts*; then
    say Chowning
    chown -R $(id -u):$(id -g) /ref

    say Comparing against reference
    ( cd \$odir
    say Porcelain...
    git status --porcelain
    [[ '0' = "\$(git status --porcelain | wc -l)" ]]
    )
    say Same-same
else
    exit 1
fi

EOF
