#!/bin/bash

# Generate docs for erldocs, display the diff

set -e
mkdir -p doc
rm -rf doc/* >/dev/null
./_build/default/bin/erldocs -o doc/ .
rm -r doc/.xml/
errors=$(git status --porcelain -- doc/ | wc -l)
git status --porcelain -- doc/
git diff -- doc/
exit $errors
