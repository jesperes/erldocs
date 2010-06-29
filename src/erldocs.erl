-module(erldocs).
-export([ copy_static_files/1, build/1 ]).

%% @doc Copy static files
-spec copy_static_files(list()) -> ok.
copy_static_files(Conf) ->
    [ {ok, _} = file:copy([static(Conf), "/", File], [dest(Conf), "/", File])
      || File <- static_files() ],
    ok.

%% @doc Build everything
-spec build(list()) -> ok.
build(Conf) ->

    filelib:ensure_dir(dest(Conf)),
    
    {ok, Bin} = file:read_file([static(Conf), "/", "erldocs.tpl"]),
    Tpl       = binary_to_list(Bin),
    
    Fun   = fun(X, Y) -> build_apps(Conf, Tpl, X, Y) end,
    Index = strip_cos(lists:foldl(Fun, [], app_dirs(Conf))),

    ok = module_index(Conf, Index),
    ok = javascript_index(Conf, Index),                     
    ok = copy_static_files(Conf).

build_apps(Conf, Tpl, App, Index) ->
    Files   = ensure_docsrc(App),
    AppName = bname(App),
    log("Building ~s (~p files)~n", [AppName, length(Files)]),
    Fun = fun(X, Acc) -> build_files(Conf, Tpl, AppName, X, Acc) end,
    lists:foldl(Fun, Index, Files).

build_files(Conf, Tpl, AppName, File, Index) ->
    
    log("  + ~p~n", [bname(File)]),
    {Type, _Attr, Content} = read_xml(Conf, File),
    
    case lists:member(Type, buildable()) of
        false -> Index;
        true  ->

            Module = bname(File, ".xml"),
            Xml = strip_whitespace(Content),
           
            Sum2 = case Type of
                       erlref ->                    
                           {modulesummary, [], Sum}
                               = lists:keyfind(modulesummary,1, Xml),
                           Sum;
                       cref ->
                           {libsummary, [], Sum}
                               = lists:keyfind(libsummary, 1, Xml),
                           Sum
                  end,
            
            Sum1 = lists:flatten(Sum2),
            
            % strip silly shy characters
            Funs = get_funs(AppName, Module, lists:keyfind(funcs, 1, Xml)),
            
            ok = render(Type, AppName, Module, Content, Conf, Tpl),
            
            case lists:member({AppName, Module}, ignore()) of
                true -> Index;
                false ->
                    lists:append([ ["mod", AppName, Module, Sum1] |  Funs],
                                 Index)
            end
    end.
    
%% @doc strip out the cos* files from the index, who the hell needs them
%% anyway
-spec strip_cos(list()) -> list().
strip_cos(Index) ->
    [X || X = [_, App |_] <- Index, nomatch == re:run(App, "^cos") ].

ensure_docsrc(AppDir) ->
    case filelib:is_dir(AppDir ++ "/doc/src/") of
        true  -> filelib:wildcard(AppDir ++ "/doc/src/*.xml");
        false ->
            log("No docs for ~s, attempting to build~n", [bname(AppDir)]),
            tmp_cd(AppDir ++ "/doc/src/", fun() -> gen_docsrc(AppDir) end)
    end.    

gen_docsrc(AppDir) ->
    [ begin
          ok = docb_gen:module(File),
          AppDir ++ "/doc/src/" ++ bname(File, ".erl") ++ ".xml"
      end || File <- filelib:wildcard(AppDir ++ "/src/*.erl") ].

%% @doc run a function with the cwd set, ensuring the cwd is reset once
%% finished (some dumb functions require to be ran from a particular dir)
-spec tmp_cd(list(), fun()) -> term().
tmp_cd(Dir, Fun) ->
    
    {ok, OldDir} = file:get_cwd(),
    
    ok = filelib:ensure_dir(Dir),
    ok = file:set_cwd(Dir),
    
    try
        Result = Fun(),
        ok = file:set_cwd(OldDir),
        Result
    catch
        Type:Err ->
            ok = file:set_cwd(OldDir),
            throw({Type, Err})
    end.
            
    
module_index(Conf, Index) ->

    log("Creating index.html ...~n"),
    
    Html = "<h1>Module Index</h1><hr /><br /><div>"
        ++ xml_to_str([ mod(X) || X = ["mod"|_] <- lists:sort(Index)])
        ++ "</div>",
    
    Args = [{base,    "./"},
            {title,   "Module Index - " ++ kf(name, Conf)},
            {content, Html},
            {funs,    ""}],

    ok = file:write_file([dest(Conf), "/index.html"],
                         file_tpl(Args, load_tpl(Conf))).

mod(["mod", App, Mod, Sum]) ->
    Url = App ++ "/" ++ Mod ++ ".html",
    {p,[], [{a, [{href, Url}], [Mod]}, {br,[],[]}, Sum]}.

sort_index(["app" | _], ["mod" | _])             -> true;
sort_index(["app" | _], ["fun" | _])             -> true;
sort_index(["mod" | _], ["fun" | _])             -> true;
sort_index(["mod", _, M1, _], ["mod", _, M2, _]) ->
    string:to_lower(M1) < string:to_lower(M2);
sort_index(_, _)                                 -> false.
    
javascript_index(Conf, FIndex) ->

    log("Creating erldocs_index.js ...~n"),
    
    F = fun([Else, App, NMod, Sum]) ->
                [Else, App, NMod, string:substr(Sum, 1, 50)]
        end,
    
    Index = lists:sort( fun(X, Y) -> sort_index(X, Y) end,
                        [ F(X) || X <- FIndex ] ),
    Js    = fmt("var index = ~p;", [Index]),
    
    ok = file:write_file([dest(Conf), "/erldocs_index.js"], Js).

render(cref, App, Mod, Xml, Conf, Tpl) ->
    render(erlref, App, Mod, Xml, Conf, Tpl);

render(erlref, App, Mod, Xml, Conf, Tpl) ->
    
    File = filename:join([dest(Conf), App, Mod ++ ".html"]),
    ok   = filelib:ensure_dir(filename:dirname(File) ++ "/"),
    
    Acc = [{ids,[]}, {list, ul}, {functions, []}],
    {[_Id, _List, {functions, Funs}], NXml}
        = render(fun tr_erlref/2,  Xml, Acc),
    
    XmlFuns = [{li, [], [{a, [{href, "#"++X}], [X]}]}
                || X <- lists:reverse(Funs) ],
        
    Args = [{base,    "../"},
            {title,   Mod ++ " - " ++ kf(name, Conf)},
            {content, xml_to_str(NXml)},
            {funs,    xml_to_str({ul, [{id, "funs"}], XmlFuns})}],
    
    ok = file:write_file(File, file_tpl(Args, Tpl)).

render(Fun, List, Acc) when is_list(List) ->
    case io_lib:char_list(List) of 
        true  ->
            {Acc, List};
        false ->
            F = fun(X, {Ac, L}) ->
                        {NAcc, NEl} = render(Fun, X, Ac),
                        {NAcc, [NEl | L]}
                end,
            
            {Ac, L} = lists:foldl(F, {Acc, []}, List),
            {Ac, lists:reverse(L)}
    end;

render(Fun, Element, Acc) ->

    % this is nasty
    F = fun(ignore, NAcc) ->
                {NAcc, ""};
           ({NEl, NAttr, NChild}, NAcc) ->
                {NNAcc, NNChild} = render(Fun, NChild, NAcc),
                {NNAcc, {NEl, NAttr, NNChild}};
           (Else, NAcc) ->
                {NAcc, Else}
        end,
    
    case Fun(Element, Acc) of
        {El, NAcc} -> F(El, NAcc);
        El         -> F(El, Acc)
    end.

get_funs(_App, _Mod, false) ->
    [];
get_funs(App, Mod, {funcs, [], Funs}) ->
    lists:foldl(
            fun(X, Acc) -> fun_stuff(App, Mod, X) ++ Acc end,
            [], Funs).

fun_stuff(App, Mod, {func, [], Child}) ->
    
    {fsummary, [], Xml} = lists:keyfind(fsummary, 1, Child),
    Summary = string:substr(xml_to_str(Xml), 1, 50),
    
    F = fun({name, [], Name}, Acc) ->
                case make_name(Name) of
                    ignore -> Acc;
                    NName  -> [ ["fun", App, Mod++":"++NName, Summary] | Acc ]
                end;
           (_Else, Acc) -> Acc
        end,
    
    lists:foldl(F, [], Child).

make_name(Name) ->
    Tmp = lists:flatten(Name),
    case string:chr(Tmp, 40) of
        0 ->
            %io:format("wtf ~p~n",[Name]),
            ignore;
        Pos ->
            {Name2, Rest2} = lists:split(Pos-1, Tmp),
            Name3          = lists:last(string:tokens(Name2, ":")),
            Args           = string:substr(Rest2, 2, string:chr(Rest2, 41)-2),
            NArgs          = length(string:tokens(Args, ",")),
            Name3 ++ "/" ++ integer_to_list(NArgs)
    end.

app_dirs(Conf) ->
    Fun = fun(Path, Acc) ->
                  Acc ++ [X || X <- filelib:wildcard(Path), filelib:is_dir(X)]
          end,
    lists:foldl(Fun, [], kf(apps, Conf)).

add_html("#"++Rest) ->
    "#"++Rest;
add_html(Link) ->
    case string:tokens(Link, "#") of
        [Tmp]    -> Tmp++".html";
        [N1, N2] -> lists:flatten([N1, ".html#", N2])
    end.     

%% Transforms erlang xml format to html
tr_erlref({header,[],_Child}, _Acc) ->
    ignore;
tr_erlref({marker, [{id, Marker}], []}, _Acc) ->
    {span, [{id, Marker}], [" "]};
tr_erlref({term,[{id, Term}], _Child}, _Acc) ->
    Term;
tr_erlref({lib,[],Lib}, _Acc) ->
    {h1, [], [lists:flatten(Lib)]};
tr_erlref({module,[],Module}, _Acc) ->
    {h1, [], [lists:flatten(Module)]};
tr_erlref({modulesummary, [], Child}, _Acc) ->
    {h2, [{class, "modsummary"}], Child};
tr_erlref({c, [], Child}, _Acc) ->
    {code, [], Child};
tr_erlref({section, [], Child}, _Acc) ->
    {'div', [{class, "section"}], Child};
tr_erlref({title, [], Child}, _Acc) ->
    {h4, [], [Child]};
tr_erlref({type, [], Child}, _Acc) ->
    {ul, [{class, "type"}], Child};
tr_erlref({v, [], []}, _Acc) ->
    {li, [], [" "]};
tr_erlref({v, [], Child}, _Acc) ->
    {li, [], [{code, [], Child}]};
tr_erlref({seealso, [{marker, Marker}], Child}, _Acc) ->
    N = case string:tokens(Marker, ":") of
	    [Tmp]     -> add_html(Tmp);
	    [Ap | Md] ->  "../"++Ap++"/" ++ add_html(lists:flatten(Md))
	end,
    {a, [{href, N}, {class, "seealso"}], Child};
tr_erlref({desc, [], Child}, _Acc) ->
    {'div', [{class, "description"}], Child};
tr_erlref({description, [], Child}, _Acc) ->
    {'div', [{class, "description"}], Child};
tr_erlref({funcs, [], Child}, _Acc) ->
    {'div', [{class,"functions"}], [{h4, [], ["Functions"]},
                                    {hr, [], []} | Child]};
tr_erlref({func, [], Child}, _Acc) ->
    {'div', [{class,"function"}], Child};
tr_erlref({tag, [], Child}, _Acc) ->
    {dt, [], Child};
tr_erlref({taglist, [], Child}, [Ids, _List, Funs]) ->
    { {dl, [], Child}, [Ids, {list, dl}, Funs] };
tr_erlref({input, [], Child}, _Acc) ->
    {code, [], Child};
tr_erlref({item, [], Child}, [_Ids, {list, dl}, _Funs]) ->
    {dd, [], Child};
tr_erlref({item, [], Child}, [_Ids, {list, ul}, _Funs]) ->
    {li, [], Child};
tr_erlref({list, _Type, Child}, [Ids, _List, Funs]) ->
    { {ul, [], Child}, [Ids, {list, ul}, Funs] };
tr_erlref({code, [{type, "none"}], Child}, _Acc) ->
    {pre, [{class, "sh_erlang"}], Child};
tr_erlref({pre, [], Child}, _Acc) ->
    {pre, [{class, "sh_erlang"}], Child};
tr_erlref({note, [], Child}, _Acc) ->
    {'div', [{class, "note"}], [{h2, [], ["Note!"]} | Child]};
tr_erlref({warning, [], Child}, _Acc) ->
    {'div', [{class, "warning"}], [{h2, [], ["Warning!"]} | Child]};
tr_erlref({name, [], Child}, [{ids, Ids}, List, {functions, Funs}]) ->
    case make_name(Child) of
        ignore -> ignore;
        Name   ->
            NName = inc_name(Name, Ids, 0),
            { {h3, [{id, NName}], [Child]},     
              [{ids, [NName | Ids]}, List, {functions, [NName|Funs]}]}
    end;
tr_erlref({fsummary, [], _Child}, _Acc) ->
    ignore;
tr_erlref(Else, _Acc) ->
    Else.

nname(Name, 0)   -> Name;
nname(Name, Acc) -> Name ++ "-" ++ integer_to_list(Acc).

inc_name(Name, List, Acc) ->
    case lists:member(nname(Name, Acc), List) of
        true   -> inc_name(Name, List, Acc+1);
        false  -> nname(Name, Acc)
    end.

%% Strips xml children that are entirely whitespace (space, tabs, newlines)
strip_whitespace(List) when is_list(List) ->
    [ strip_whitespace(X) || X <- List, is_whitespace(X) ]; 
strip_whitespace({El,Attr,Children}) ->
    {El, Attr, strip_whitespace(Children)};
strip_whitespace(Else) ->
    Else.

is_whitespace(X) when is_tuple(X); is_number(X) ->
    true;
is_whitespace(X) ->
    nomatch == re:run(X, "^[ \n\t]*$"). %"

%% rather basic xml to string converter, takes xml of the form
%% {tag, [{listof, "attributes"}], ["list of children"]}
%% into <tag listof="attributes">list of children</tag>
xml_to_str(Xml) ->
    xml_to_html(Xml).

xml_to_html({Tag, Attr, []}) ->
    fmt("<~s ~s />", [Tag, atos(Attr)]);
xml_to_html({Tag, [], []}) ->
    fmt("<~s />", [Tag]);
xml_to_html({Tag, [], Child}) ->
    fmt("<~s>~s</~s>", [Tag, xml_to_html(Child), Tag]);
xml_to_html({Tag, Attr, Child}) ->
    fmt("<~s ~s>~s</~s>", [Tag, atos(Attr), xml_to_html(Child), Tag]);
xml_to_html(List) when is_list(List) ->
    case io_lib:char_list(List) of
        true  -> htmlchars(List);
        false -> lists:flatten([ xml_to_html(X) || X <- List])
    end.

atos([])                      -> "";
atos(List) when is_list(List) -> string:join([ atos(X) || X <- List ], " ");
atos({Name, Val})             -> atom_to_list(Name) ++ "=\""++Val++"\"".

%% convert ascii into html characters
htmlchars(List) ->
    htmlchars(List, []).

htmlchars([], Acc) ->
    lists:flatten(lists:reverse(Acc));

htmlchars([$<   | Rest], Acc) -> htmlchars(Rest, ["&lt;" | Acc]);
htmlchars([$>   | Rest], Acc) -> htmlchars(Rest, ["&gt;" | Acc]);
htmlchars([160  | Rest], Acc) -> htmlchars(Rest, ["&nbsp;" | Acc]);
htmlchars([Else | Rest], Acc) -> htmlchars(Rest, [Else | Acc]).

%% @doc parse xml file against otp's dtd, need to cd into the
%% source directory because files are addressed relative to it
-spec read_xml(list(), list()) -> tuple().    
read_xml(Conf, XmlFile) ->

    Opts  = [{fetch_path, [kf(root, Conf) ++ "/priv/dtd/"]},
             {encoding,   "latin1"}],

    Fun = fun() ->
                  {ok, Bin} = file:read_file(XmlFile),
                  {Xml, _}  = xmerl_scan:string(binary_to_list(Bin), Opts),
                  xmerl_lib:simplify_element(Xml)
          end,
    
    tmp_cd(filename:dirname(XmlFile), Fun).

%% Quick and dirty templating functions (replaces #KEY# in html with
%% {key, "Some text"}
load_tpl(Conf) ->
    {ok, Bin} = file:read_file([static(Conf), "/","erldocs.tpl"]),
    binary_to_list(Bin).

file_tpl(Args, Tpl) ->
    str_tpl(Tpl, Args).
    
str_tpl(Str, Args) ->
    F = fun({Key, Value}, Tpl) ->
                % re: goes nuts with memory usage, need to replace anyway
                %Opts = [global],               
                %re:replace(Tpl, NKey, esc_regex(Value), Opts)
                NKey = "#"++string:to_upper(atom_to_list(Key))++"#",
                {ok, NTpl, _} = regexp:gsub(Tpl, NKey, esc_regex(Value)),
                NTpl
        end,
    lists:foldr(F, Str, Args).

%% lazy shorthand
fmt(Format, Args) ->
    lists:flatten(io_lib:format(Format, Args)).

%% Escape the replacement part of the regular expression
%% so no spurios replacements
esc_regex(List) when is_binary(List) ->    
    esc_regex(binary_to_list(List));
esc_regex(List) ->    
    esc_regex(List, []).

esc_regex([], Acc) ->
    lists:flatten(lists:reverse(Acc));

esc_regex([$&   | Rest], Acc) -> esc_regex(Rest, ["\\&" | Acc]);
esc_regex([Else | Rest], Acc) -> esc_regex(Rest, [Else | Acc]).

log(Str) ->
    io:format(Str).
log(Str, Args) ->
    io:format(Str, Args).

%% @doc shorthand for lists:keyfind
-spec kf(term(), list()) -> term().
kf(Key, Conf) ->
    {Key, Val} = lists:keyfind(Key, 1, Conf),
    Val.

%% @doc path to the destination folder
-spec dest(list()) -> list().
dest(Conf) ->
    [kf(root, Conf), "/priv/www/", kf(name, Conf), "/"].

%% @doc path to static files
-spec static(list()) -> list().
static(Conf) ->
    [kf(root, Conf), "/priv/static/"].

bname(Name) ->
    filename:basename(Name).
bname(Name, Ext) ->
    filename:basename(Name, Ext).

% List of the type of xml files erldocs can build
buildable() ->
    [ erlref, cref ].

static_files() ->
    ["erldocs.js", "erldocs.css", "jquery.js"].

ignore() ->
    [{"kernel", "init"},
     {"kernel", "zlib"},
     {"kernel", "erlang"},
     {"kernel", "erl_prim_loader"}].
