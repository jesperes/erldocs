#!/bin/bash -eu

[[ $# -ne 1 ]] && echo "Usage: $0  <kerl OTP release>" && exit 2
rel=$1
rel_path=test/otp_rel
ref_path=test/otp_ref
which kerl >/dev/null
kerl_path="$(which kerl)"

[[ -d _build ]] && exit 3

mkdir -p $rel_path $ref_path
docker run --rm --interactive \
       --volume "$kerl_path":/usr/local/bin/kerl:ro \
       --volume "$PWD":/app/erldocs:rw \
       --volume "$PWD"/$rel_path:/rel:rw \
       --volume "$PWD"/$ref_path:/ref:rw \
       --volume "$PWD"/test/job.sh:/app/run/job.sh:ro \
       alpine:3.7 \
       /app/run/job.sh "$rel" "$(id -u)" "$(id -g)"
