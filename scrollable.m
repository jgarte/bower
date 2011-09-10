%-----------------------------------------------------------------------------%

:- module scrollable.
:- interface.

:- import_module bool.
:- import_module io.
:- import_module list.
:- import_module version_array.

:- import_module curs.
:- import_module curs.panel.

%-----------------------------------------------------------------------------%

:- type scrollable(T).

:- typeclass line(T) where [
    pred draw_line(panel::in, T::in, bool::in, io::di, io::uo) is det
].

:- func init(list(T)) = scrollable(T).

:- func init_with_cursor(list(T), int) = scrollable(T).

:- func get_lines(scrollable(T)) = version_array(T).

:- func get_num_lines(scrollable(T)) = int.

:- func get_top(scrollable(T)) = int.

:- pred set_top(int::in, scrollable(T)::in, scrollable(T)::out) is det.

:- pred get_cursor(scrollable(T)::in, int::out) is semidet.

:- pred set_cursor(int::in, scrollable(T)::in, scrollable(T)::out) is det.

:- pred set_cursor_centred(int::in, int::in,
    scrollable(T)::in, scrollable(T)::out) is det.

:- pred get_cursor_line(scrollable(T)::in, int::out, T::out) is semidet.

:- pred set_cursor_line(T::in, scrollable(T)::in, scrollable(T)::out) is det.

:- pred map_lines(pred(T, T)::in(pred(in, out) is det),
    scrollable(T)::in, scrollable(T)::out) is det.

:- pred scroll(int::in, int::in, bool::out,
    scrollable(T)::in, scrollable(T)::out) is det.

:- pred move_cursor(int::in, int::in, bool::out,
    scrollable(T)::in, scrollable(T)::out) is det.

:- pred search_forward(pred(T)::in(pred(in) is semidet),
    scrollable(T)::in, int::in, int::out, T::out) is semidet.

:- pred search_forward_limit(pred(T)::in(pred(in) is semidet),
    scrollable(T)::in, int::in, int::in, int::out, T::out) is semidet.

:- pred search_reverse(pred(T)::in(pred(in) is semidet),
    scrollable(T)::in, int::in, int::out) is semidet.

:- pred draw(list(panel)::in, scrollable(T)::in, io::di, io::uo) is det
    <= scrollable.line(T).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module int.
:- import_module maybe.
:- import_module require.
:- import_module version_array.

:- type scrollable(T)
    --->    scrollable(
                s_lines     :: version_array(T),
                s_top       :: int,
                s_cursor    :: maybe(int)
            ).

%-----------------------------------------------------------------------------%

init(Lines) = Scrollable :-
    LinesArray = version_array.from_list(Lines),
    Top = 0,
    Scrollable = scrollable(LinesArray, Top, no).

init_with_cursor(Lines, Cursor) = Scrollable :-
    LinesArray = version_array.from_list(Lines),
    Top = 0,
    Scrollable = scrollable(LinesArray, Top, yes(Cursor)).

get_lines(Scrollable) = Scrollable ^ s_lines.

get_num_lines(Scrollable) = size(Scrollable ^ s_lines).

get_top(Scrollable) = Scrollable ^ s_top.

set_top(Top, !Scrollable) :-
    !Scrollable ^ s_top := Top.

get_cursor(Scrollable, Cursor) :-
    Scrollable ^ s_cursor = yes(Cursor).

set_cursor(Cursor, !Scrollable) :-
    !Scrollable ^ s_cursor := yes(Cursor).

set_cursor_centred(Cursor, NumRows, !Scrollable) :-
    Top = max(0, Cursor - NumRows//2),
    !Scrollable ^ s_top := Top,
    !Scrollable ^ s_cursor := yes(Cursor).

get_cursor_line(Scrollable, Cursor, Line) :-
    Lines = Scrollable ^ s_lines,
    MaybeCursor = Scrollable ^ s_cursor,
    MaybeCursor = yes(Cursor),
    Line = version_array.lookup(Lines, Cursor).

set_cursor_line(Line, !Scrollable) :-
    (
        !.Scrollable ^ s_lines = Lines0,
        !.Scrollable ^ s_cursor = yes(Cursor)
    ->
        version_array.set(Cursor, Line, Lines0, Lines),
        !Scrollable ^ s_lines := Lines
    ;
        unexpected($module, $pred, "failed")
    ).

map_lines(P, !Scrollable) :-
    !.Scrollable ^ s_lines = Array0,
    List0 = version_array.to_list(Array0),
    list.map(P, List0, List),
    !Scrollable ^ s_lines := version_array.from_list(List).

scroll(NumRows, Delta, HitLimit, !Scrollable) :-
    !.Scrollable = scrollable(Lines, Top0, MaybeCursor0),
    NumLines = version_array.size(Lines),
    TopLimit = max(max(0, NumLines - NumRows), Top0),
    Top = clamp(0, Top0 + Delta, TopLimit),
    ( Top = Top0, Delta < 0 ->
        HitLimit = yes
    ; Top = Top0, Delta > 0 ->
        HitLimit = yes
    ;
        HitLimit = no
    ),
    % XXX cursor
    MaybeCursor = MaybeCursor0,
    !:Scrollable = scrollable(Lines, Top, MaybeCursor).

move_cursor(NumRows, Delta, HitLimit, !Scrollable) :-
    !.Scrollable = scrollable(Lines, Top0, MaybeCursor0),
    NumLines = version_array.size(Lines),
    (
        MaybeCursor0 = yes(Cursor0),
        Cursor = clamp(0, Cursor0 + Delta, NumLines - 1),
        ( Cursor = Cursor0 ->
            HitLimit = yes
        ;
            HitLimit = no,
            ( Cursor < Top0 ->
                Top = max(Cursor - NumRows + 1, 0)
            ; Top0 + NumRows - 1 < Cursor ->
                Top = Cursor
            ;
                Top = Top0
            ),
            !:Scrollable = scrollable(Lines, Top, yes(Cursor))
        )
    ;
        MaybeCursor0 = no,
        HitLimit = no
    ).

search_forward(P, Scrollable, I0, I, MatchLine) :-
    search_forward_limit(P, Scrollable, I0, int.max_int, I, MatchLine).

search_forward_limit(P, Scrollable, I0, Limit, I, MatchLine) :-
    Scrollable = scrollable(Lines, _Top, _MaybeCursor),
    Size = version_array.size(Lines),
    search_forward_2(P, Lines, int.min(Limit, Size), I0, I, MatchLine).

:- pred search_forward_2(pred(T)::in(pred(in) is semidet),
    version_array(T)::in, int::in, int::in, int::out, T::out) is semidet.

search_forward_2(P, Array, Limit, N0, N, MatchX) :-
    ( N0 < Limit ->
        X = version_array.lookup(Array, N0),
        ( P(X) ->
            N = N0,
            MatchX = X
        ;
            search_forward_2(P, Array, Limit, N0 + 1, N, MatchX)
        )
    ;
        fail
    ).

search_reverse(P, Scrollable, I0, I) :-
    Scrollable = scrollable(Lines, _Top, _MaybeCursor),
    search_reverse_2(P, Lines, I0 - 1, I, _).

:- pred search_reverse_2(pred(T)::in(pred(in) is semidet),
    version_array(T)::in, int::in, int::out, T::out) is semidet.

search_reverse_2(P, Array, N0, N, MatchX) :-
    ( N0 >= 0 ->
        X = version_array.lookup(Array, N0),
        ( P(X) ->
            N = N0,
            MatchX = X
        ;
            search_reverse_2(P, Array, N0 - 1, N, MatchX)
        )
    ;
        fail
    ).

draw(RowPanels, Scrollable, !IO) :-
    Scrollable = scrollable(Lines, Top, MaybeCursor),
    (
        MaybeCursor = yes(Cursor)
    ;
        MaybeCursor = no,
        Cursor = -1
    ),
    draw_lines(RowPanels, Lines, Top, Cursor, !IO).

:- pred draw_lines(list(panel)::in, version_array(T)::in, int::in, int::in,
    io::di, io::uo) is det
    <= scrollable.line(T).

draw_lines([], _, _, _, !IO).
draw_lines([Panel | Panels], Lines, I, Cursor, !IO) :-
    panel.erase(Panel, !IO),
    Size = version_array.size(Lines),
    ( I < Size ->
        Line = version_array.lookup(Lines, I),
        IsCursor = (I = Cursor -> yes ; no),
        draw_line(Panel, Line, IsCursor, !IO)
    ;
        true
    ),
    draw_lines(Panels, Lines, I + 1, Cursor, !IO).

:- func clamp(int, int, int) = int.

clamp(Min, X, Max) =
    ( X < Min -> Min
    ; X > Max -> Max
    ; X
    ).

%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sts=4 sw=4 et
