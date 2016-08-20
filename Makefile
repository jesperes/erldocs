REBAR3 ?= rebar3

all: escript | erl.mk

erl.mk:
	curl -fsSLo $@ 'https://raw.github.com/fenollp/erl-mk/master/erl.mk' || rm $@

dep_erlydtl = https://github.com/erlydtl/erlydtl 0.12.0

ERLCFLAGS += +debug_info

-include erl.mk
# Your targets after this line.
.PHONY: clean distclean test

clean: clean-ebin

distclean: clean clean-escript clean-deps
	$(if $(wildcard erl.mk), rm erl.mk)

debug: debug-app

unit_tests:
	$(REBAR3) eunit
test: unit_tests
	./test/check.sh
	./test/find-slashed-function-names.sh doc/
#	./test/test.sh /tmp/erldocs.git

dialyze: app
	dialyzer --src src/ --plt ~/.dialyzer_plt --no_native  -Werror_handling -Wrace_conditions -Wunmatched_returns -Wunderspecs
