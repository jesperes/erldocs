%% Copyright © 2015 Pierre Fenoll ‹pierrefenoll@gmail.com›
%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(erldocs_core_tests).

%% erldocs_core_tests: tests for module erldocs_core.

-include_lib("eunit/include/eunit.hrl").

-define(MODULE_TESTED, erldocs_core).

%% API tests.

includes_test () ->
    AppDir = filename:dirname(filename:dirname(filename:absname(?FILE))),
    Expected = [ ""
               , "erldocs"
               , "erldocs/deps"
               , "erldocs/deps/erlydtl"
               , "erldocs/deps/erlydtl/include"
               , "erldocs/include"
               ],
    IncludePaths = ?MODULE_TESTED:includes(AppDir),
    Got = rm_dotgit(rm_merl(frps(filename:dirname(AppDir), IncludePaths))),
    ?assertEqual(Expected, Got).

%% Internals

frps (Prefix, Paths) ->
    [?MODULE_TESTED:filename__remove_prefix(Prefix, Path) || Path <- Paths].

rm_merl (Paths) ->
    [Path || Path <- Paths,
             not lists:member("merl", filename:split(Path))].

rm_dotgit (Paths) ->
    [binary_to_list(
       binary:replace(list_to_binary(Path), <<"erldocs.git">>, <<"erldocs">>)
      )
     || Path <- Paths].

%% End of Module.
