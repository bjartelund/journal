%% -*- mode: nitrogen -*-
-module (index).
-compile(export_all).
-include_lib("nitrogen_core/include/wf.hrl").
%% Attempt typical nitrogen elements include (wrapped in -ifdef to avoid compile failure if not present)
-ifdef(NITROGEN).
-include_lib("nitrogen/include/nitrogen.hrl").
-endif.

main() -> #template { file=template_path() }.

template_path() ->
    filename:join([code:priv_dir(journal), "templates", "bare.html"]).

title() -> "Welcome to journal".

body() ->
    #container_12 { body=[
        #grid_8 { alpha=true, prefix=2, suffix=2, omega=true, body=inner_body() }
    ]}.

inner_body() -> 
    [
        #h1 { text="Welcome to my journal." },
        #p { text="Enter a new journal entry and click save." },
    %% Multiline textarea replacing single-line textbox
    %% Nitrogen 3 textarea record uses 'columns' not 'cols'
    #textarea { id=input1, text="", rows=10, columns=80, html_encode=true, style="width:100%;" },
        #button { id=save_btn, text="Save entry", postback=click },
        #hr {},
        #panel { id=entries_panel, body=journal_entries_elements() }
    ].
	
event(click) ->
    Input = wf:q(input1),
    Trimmed = string:trim(Input),
    case Trimmed of
        "" -> wf:wire(#alert { text="Cannot save empty entry." });
        _ ->
            {{Y, M, D}, {H, Min, S}} = calendar:now_to_universal_time(os:timestamp()),
            ensure_journal_dir(),
            Filename = io_lib:format("~s/journal_~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B.txt", [journal_dir(), Y, M, D, H, Min, S]),
            ok = write_to_file(Filename, Trimmed),
            wf:replace(entries_panel, #panel { id=entries_panel, body=journal_entries_elements() }),
            %% Clear textbox by updating its value attribute via direct script (simpler than #set when unavailable)
            wf:wire("document.getElementById('input1').value='';"),
            wf:flash("Entry saved.")
    end.

write_to_file(Filename, Content) ->
    {ok, File} = file:open(Filename, [write]),
    ok = io:format(File, "~s", [Content]),
    file:close(File).

%% Fetch journal entries from files matching journal_*.txt
journal_entries_elements() ->
    ensure_journal_dir(),
    Pattern = filename:join(journal_dir(), "journal_*.txt"),
    case filelib:wildcard(Pattern) of
        [] -> [#p { text="No entries yet." }];
        Files ->
            Entries = lists:filtermap(fun parse_journal_file/1, Files),
            Sorted = lists:sort(fun({TS1,_},{TS2,_}) -> TS1 > TS2 end, Entries),
            [ #panel { class="journal_entry", body=[ #h3 { text=Title }, #pre { text=html_escape(Content) } ] } || {_TS,{Title,Content}} <- Sorted ]
    end.

parse_journal_file(Filename) ->
    case re:run(Filename, "journal_(\\d{4}-\\d{2}-\\d{2})T(\\d{2}:\\d{2}:\\d{2})\\.txt", [{capture, all_but_first, list}]) of
        {match, [Date, Time]} ->
            TS = iso_to_ts(Date, Time),
            case file:read_file(Filename) of
                {ok, Bin} -> {true, {TS, {Date ++ " " ++ Time, binary_to_list(Bin)}}};
                _ -> false
            end;
        nomatch -> false
    end.

journal_dir() -> filename:join([code:priv_dir(journal), "journal"]).

ensure_journal_dir() ->
    Dir = journal_dir(),
    case file:read_file_info(Dir) of
        {ok, _} -> ok;
        {error, enoent} -> file:make_dir(Dir), ok;
        _ -> ok
    end.

iso_to_ts(Date, Time) ->
    {Y,M,D} = parse_date(Date),
    {H,Min,S} = parse_time(Time),
    calendar:datetime_to_gregorian_seconds({{Y,M,D},{H,Min,S}}).

parse_date(DateStr) ->
    [Ystr,Mstr,Dstr] = string:tokens(DateStr, "-"),
    {list_to_integer(Ystr), list_to_integer(Mstr), list_to_integer(Dstr)}.

parse_time(TimeStr) ->
    [Hstr,Minstr,Sstr] = string:tokens(TimeStr, ":"),
    {list_to_integer(Hstr), list_to_integer(Minstr), list_to_integer(Sstr)}.

html_escape(S) when is_list(S) ->
    lists:flatten([escape_char(C) || C <- S]);
html_escape(B) when is_binary(B) ->
    html_escape(binary_to_list(B)).

escape_char($<) -> "&lt;";
escape_char($>) -> "&gt;";
escape_char($&) -> "&amp;";
escape_char($\") -> "&quot;";
escape_char(C) -> [C].
