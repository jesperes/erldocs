#!/bin/bash

# Find functions & types ~ Name/Arity
# Error if return set is non-empty, as F&Ts should be maximally expanded

grep -irIEn --color=auto '<h3.*?>[^>/]+/[^/<]+<' $*

[[ $? -ne 0 ]] && exit 0 || exit 1
