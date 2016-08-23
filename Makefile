REBAR3 ?= rebar3

.PHONY: all distclean dialyze

all: _build/default/bin/erldocs
_build/default/bin/erldocs:
	$(REBAR3) compile

unit_tests: all
	$(REBAR3) eunit
test: unit_tests
	./test/check.sh
	./test/find-slashed-function-names.sh doc/
#	./test/test.sh /tmp/erldocs.git

dialyze:
	dialyzer --src src/ --plt ~/.dialyzer_plt --no_native  -Werror_handling -Wrace_conditions -Wunmatched_returns -Wunderspecs

distclean:
	$(if $(wildcard _build), rm -rf _build)
