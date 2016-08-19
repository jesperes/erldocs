%% Copyright © 2015 Pierre Fenoll ‹pierrefenoll@gmail.com›
%% See LICENSE for licensing information.
%% -*- coding: utf-8 -*-
-module(erldocs_core_tests).

%% erldocs_core_tests: tests for module erldocs_core.

-include_lib("eunit/include/eunit.hrl").

-define(MODULE_TESTED, erldocs_core).

%% API tests.

includes_test () ->
    {ok, ErldocsDotGit} = file:get_cwd(),
    Expected = [""
               ,"erldocs"
               ,"erldocs/_build"
               ,"erldocs/_build/default"
               ,"erldocs/_build/default/lib"
               ,"erldocs/_build/default/lib/erldocs"
               ,"erldocs/_build/default/lib/erldocs/include"
               ,"erldocs/_build/default/lib/erlydtl"
               ,"erldocs/_build/default/lib/erlydtl/include"
               ,"erldocs/include"
               ],
    IncludePaths = ?MODULE_TESTED:includes(ErldocsDotGit),
    Got = rm_dotgit(rm_merl(frps(filename:dirname(ErldocsDotGit), IncludePaths))),
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
