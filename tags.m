% Bower - a frontend for the Notmuch email system
% Copyright (C) 2012 Peter Wang

:- module tags.
:- interface.

:- import_module data.

:- import_module list.
:- import_module set.

:- type new
    --->    new
    ;       old.

:- type unread
    --->    unread
    ;       read.

:- type replied
    --->    replied
    ;       not_replied.

:- type deleted
    --->    deleted
    ;       not_deleted.

:- type flagged
    --->    flagged
    ;       unflagged.

:- pred standard_tag(tag::in) is semidet.

:- pred get_standard_tag_state(set(tag)::in,
    unread::out, replied::out, deleted::out, flagged::out) is det.

:- pred divide_tag_deltas(list(string)::in, set(tag)::out, set(tag)::out)
    is semidet.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module string.

%-----------------------------------------------------------------------------%

standard_tag(tag("deleted")).
standard_tag(tag("flagged")).
standard_tag(tag("inbox")).
standard_tag(tag("new")).
standard_tag(tag("replied")).
standard_tag(tag("sent")).
standard_tag(tag("signed")).
standard_tag(tag("unread")).

%-----------------------------------------------------------------------------%

get_standard_tag_state(Tags, Unread, Replied, Deleted, Flagged) :-
    Unread = ( set.contains(Tags, tag("unread")) -> unread ; read ),
    Replied = ( set.contains(Tags, tag("replied")) -> replied ; not_replied ),
    Deleted = ( set.contains(Tags, tag("deleted")) -> deleted ; not_deleted ),
    Flagged = ( set.contains(Tags, tag("flagged")) -> flagged ; unflagged ).

%-----------------------------------------------------------------------------%

divide_tag_deltas(TagDeltas, AddTags, RemoveTags) :-
    list.foldl2(divide_tag_delta, TagDeltas,
        set.init, AddTags, set.init, RemoveTags).

:- pred divide_tag_delta(string::in, set(tag)::in, set(tag)::out,
    set(tag)::in, set(tag)::out) is semidet.

divide_tag_delta(TagDelta, !AddTags, !RemoveTags) :-
    (
        string.remove_prefix("+", TagDelta, Tag),
        not blacklist_tag(Tag)
    ->
        set.insert(tag(Tag), !AddTags)
    ;
        string.remove_prefix("-", TagDelta, Tag),
        not blacklist_tag(Tag)
    ->
        set.insert(tag(Tag), !RemoveTags)
    ;
        fail
    ).

:- pred blacklist_tag(string::in) is semidet.

blacklist_tag("").
blacklist_tag("-").
blacklist_tag("+").

%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sts=4 sw=4 et
