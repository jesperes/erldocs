REBAR3 ?= rebar3

.PHONY: all distclean dialyze test

all:
	$(REBAR3) compile

test:
	$(REBAR3) do compile,escriptize
	./test/check.sh
	$(REBAR3) eunit
	./test/find-slashed-function-names.sh doc/
#	./test/test.sh /tmp/erldocs.git

dialyze:
	dialyzer --src src/ --plt ~/.dialyzer_plt --no_native  -Werror_handling -Wrace_conditions -Wunmatched_returns -Wunderspecs

distclean:
	$(if $(wildcard _build), rm -rf _build)
	$(if $(wildcard doc/.xml), rm -rf doc/.xml)
