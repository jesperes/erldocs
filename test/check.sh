#!/bin/bash -e

# Generate docs for erldocs, display the diff

ERLDOCS=_build/default/bin/erldocs
mkdir -p doc
rm -rf doc/* >/dev/null
./$ERLDOCS -o doc/ .
rm -r doc/.xml/
errors=$(git status --porcelain -- doc/ | wc -l)
git status --porcelain -- doc/
git diff -- doc/
exit $errors
