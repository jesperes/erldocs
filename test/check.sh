#!/bin/bash -eu

# Generate docs for erldocs, display the diff

ERLDOCS=./_build/default/bin/erldocs
DOCS=doc/$TRAVIS_OTP_RELEASE

mkdir -vp $DOCS
rm -rf $DOCS/* >/dev/null
$ERLDOCS -o $DOCS .
rm -r $DOCS/.xml/
git status --porcelain -- $DOCS/
git diff -- $DOCS/
exit $(git status --porcelain -- $DOCS/ | wc -l)
