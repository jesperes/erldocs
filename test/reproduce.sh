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
# #!/bin/bash -eux

debian_cache=/tmp/erldocs_apt_debian_cache
mkdir -p $rel_path $ref_path $debian_cache
docker run --rm --interactive \
       --volume $debian_cache:/var/cache/apt/archives:rw \
       --volume $kerl_path:$kerl_bin:ro \
       --volume "$PWD"/$erldocs:/app/erldocs:ro \
       --volume "$PWD"/$rel_path:/rel:rw \
       --volume "$PWD"/$ref_path:/ref:rw \
       debian:8 \
       /bin/bash -eux -s <<EOF
#!/bin/bash

# Setup
apt-get update && apt-get upgrade -y
apt-get install -y git curl build-essential libncurses-dev libssl-dev automake autoconf xsltproc
say() {
    printf '\n\e[1;3m%s\e[0m\n' "\$*"
}

# Fetch reference build of docs
odir=/ref/docs-$rel
if [[ ! -f /ref/docs-$rel.tar.bz2 ]]; then
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
export KERL_BASE_DIR=/rel
export KERL_BUILD_BACKEND=git
if ! [[ -f \$KERL_BASE_DIR/otp_releases ]]; then
    kerl update releases
fi
if ! grep -Fo '$rel' \$KERL_BASE_DIR/otp_releases >/dev/null; then
    say Tag '$rel' is unknown to GitHub!
    exit 1
fi

idir=\$KERL_BASE_DIR/builds/$rel/otp_src_$rel
if [[ ! -d \$idir ]]; then
    kerl build $rel $rel
fi

if [[ ! -f \$idir/lib/xmerl/doc/src/xmerl.xml ]]; then
    ( cd \$idir
      say Commencing build of $rel docs
      if MAKEFLAGS=-j6 ./otp_build setup -a && MAKEFLAGS=-j6 make docs; then
          say Built $rel docs
      else
          say Could not make $rel docs
          exit 2
      fi
    )
fi

release_local_dir=\$KERL_BASE_DIR/$rel
if [[ ! -d \$release_local_dir ]]; then
    say Installing $rel into \$release_local_dir
    if ! kerl install $rel \$release_local_dir; then
        say Could not install $rel in \$release_local_dir
        exit 3
    fi
fi
chown -R $(id -u):$(id -g) /rel
say Using erl at "\$(which erl)"
set +eux  # activate is unclean
. \$release_local_dir/activate
set -eux


# Run erldocs
pushd \$odir
for f in * .*; do
    if [[ "\$f" = .git ]] || [[ "\$f" = . ]] || [[ "\$f" = .. ]]; then
        continue
    fi
    rm -rf "\$f"
done
popd
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
