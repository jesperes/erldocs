REBAR3 ?= rebar3

.PHONY: all distclean test

all:
	$(REBAR3) compile

test: all
	$(REBAR3) eunit
	./test/check.sh
	./test/find-slashed-function-names.sh doc/
#	./test/test.sh /tmp/erldocs.git

distclean:
	$(if $(wildcard _build),rm -rf _build)
	$(if $(wildcard doc/.xml),rm -r doc/.xml)
