REBAR3 ?= rebar3

.PHONY: all distclean test

all:
	$(REBAR3) compile

test: all
	unzip -l _build/default/bin/erldocs | grep erlydtl
	$(REBAR3) eunit
	if [ ! -z $$TRAVIS_OTP_RELEASE ]; then ./test/check.sh; fi
#	./test/find-slashed-function-names.sh doc/
#	./test/test.sh /tmp/erldocs.git

FMT = _build/erlang-formatter-master/fmt.sh
$(FMT):
	mkdir -p _build/
	curl -f#SL 'https://codeload.github.com/fenollp/erlang-formatter/tar.gz/master' | tar xvz -C _build/
fmt: TO_FMT ?= .
fmt: $(FMT)
	$(if $(TO_FMT), $(FMT) $(TO_FMT))

distclean:
	$(if $(wildcard _build),rm -rf _build)
	$(if $(wildcard doc/.xml),rm -r doc/.xml)
