%%%
%%% Knowledge representation langauge used in the KB
%%% Kinds, types, properties, relations, defaults, and is_a.
%%%

:- public is_a/2, kind_of/2.
:- public kind/1, leaf_kind/1.
:- public property_value/3, related/3.
:- public process_kind_hierarchy/0.
:- public property_type/3, relation_type/3.
:- public kind_lub/3, kind_glb/3.
:- public implies_relation/2, inverse_relation/2.
:- external declare_value/3, default_value/3, declare_related/3.

test_file(integrity(_), "Ontology/integrity_checks").

:- randomizable declare_kind/2.

%%%
%%% is_a
%%% Tests for what entities are of what kinds.
%%%

%% is_a(?Object, ?Kind)
%  Object is of kind Kind.
%  Kinds are simple atoms, and exist in a lattice with entity at the top.

%is_a(Object, entity) :-
%   var(Object),
%   throw(error(enumerating_entities)).
is_a(Object, Kind) :-
   var(Object),
   var(Kind),
   throw(error("is_a/2 called with neither argument instantiated")).
% This is needed to prevent is_a(4, entity) from failing, which gets
% generated by what questions that sometimes have answers that aren't
% objects with kinds.
is_a(X, entity) :-
   (number(X) ; string(X) ; list(X)),
   !.
is_a(Object, Kind) :-
   atomic(Object),
   assertion(valid_kind(Kind), "Invalid kind"),
   is_a_aux(Object, ImmediateKind),
   superkind_array(ImmediateKind, Supers),
   array_member(Kind, Supers).
is_a(Object, Kind) :-
   var(Object),
   assertion(valid_kind(Kind), "Invalid kind"),
   subkind_array(Kind, Subs),
   array_member(Sub, Subs),
   is_a_aux(Object, Sub).

is_a_aux(Object, Kind) :-
   /brainwash/Object/kind/Kind.
is_a_aux(Object, Kind) :-
   \+ /brainwash/Object/kind,
   declare_kind(Object, Kind).

%% base_kind(+Object, -Kind)
%  Kind is the most specific type for Object
%  (technically a most specific type, since there might be more than one).
base_kind(Object, Kind) :-
   atomic(Object),
   is_a_aux(Object, Kind).

%%%
%%% Kinds and the kind hierarchy
%%%

valid_kind(Kind) :-
   var(Kind),
   !.
valid_kind(Kind) :-
   atomic(Kind),
   kind(Kind).
valid_kind(number).
valid_kind(string).

kind_of(K, K).
kind_of(Sub, Super) :-
   atomic(Sub),
   superkind_array(Sub, Supers),
   array_member(Super, Supers).
kind_of(Sub, Super) :-
   atomic(Super),
   var(Sub),
   subkind_array(Super, Subs),
   array_member(Sub, Subs).

subkind_of(Sub, Super) :-
   kind_of(Sub, Super),
   Sub \= Super.

:- public immediate_superkind_of/2.

immediate_superkind_of(K, Sub) :-
   immediate_kind_of(Sub, K).

superkinds(Kind, Superkinds) :-
   atomic(Kind),
   topological_sort([Kind], immediate_kind_of, Superkinds).

subkinds(Kind, Subkinds) :-
   atomic(Kind),
   topological_sort([Kind], immediate_superkind_of, Subkinds).

superkind_array(Kind, Array) :-
   call_with_step_limit(10000, superkinds(Kind, List)),
   list_to_array(List, Array),
   asserta( ( $global::superkind_array(Kind, Array) :- ! ) ),
   % Don't even think about trying to reexecute this.
   !.

subkind_array(Kind, Array) :-
   call_with_step_limit(10000, subkinds(Kind, List)),
   list_to_array(List, Array),
   asserta( ( $global::subkind_array(Kind, Array) :- ! ) ),
   % Don't even think about trying to reexecute this
   !.

% This version handles multiple LUBs, but then it turned out the hierarchy doesn't currently have multiple lubs.
% lub(Kind1, Kind2, LUB) :-
%    atomic(Kind1),
%    atomic(Kind2),
%    superkind_array(Kind1, A1),
%    superkind_array(Kind2, A2),
%    lub_not_including(A1, A2, LUB, []).

% lub_not_including(A1, A2, LUB, AlreadyFound) :-
%    array_member(Candidate, A1),
%    array_member(Candidate, A2),
%    \+ (member(Previous, AlreadyFound), kind_of(Previous, Candidate)),
%    !,
%    (LUB = Candidate ; lub_not_including(A1, A2, LUB, [Candidate | AlreadyFound])).

kind_lub(Kind1, Kind2, LUB) :-
   atomic(Kind1),
   atomic(Kind2),
   superkind_array(Kind1, A1),
   superkind_array(Kind2, A2),
   array_member(LUB, A1),
   array_member(LUB, A2),
   !.

kind_glb(Kind1, Kind2, GLB) :-
   atomic(Kind1),
   atomic(Kind2),
   subkind_array(Kind1, A1),
   subkind_array(Kind2, A2),
   array_member(GLB, A1),
   array_member(GLB, A2),
   !.

%%%
%%% Types
%%% This is a kluge, similar to the one in Java and C# that distinguish
%%% between types and classes.  We essentially want everything in the KB
%%% to be described in terms of kinds.
%%%
%%% The one exception is that some properties have types like string
%%% or number and is_a doesn't understand strings and numbers to be
%%% kinds.  So when checking the type of a property, we need a richer
%%% notion of types than the kind system above.  Hence "types" as an
%%% adjunct to kinds.
%%%
%%% Arguably, we should just change is_a to thing that number is a kind.
%%% The two arguments against that are that (1) it adds more special cases
%%% to is_a, and slows it down a little.  More importantly, (2), with is_a
%%% the way it is now, you can always call it with a variable for its first
%%% argument and a kind as its second, and it will start enumerating objects
%%% of that kind.  We don't want to any code that tries to enumerate all the
%%% integers, nor do we want is_a to word for enumerating objects for most
%%% kinds but not all kinds (too dangerous).
%%%
%%% Note: the one exception to the behavior of is_a is that it's been hacked
%%% to accept strings and numbers as entities because the parser just really
%%% needs that.
%%%

%% is_type(?Object, ?Type)
%  Object is of type Type.
%  Types are a super-set of kinds.
is_type(Object, number) :-
   number(Object), !.
is_type(Object, string) :-
   string(Object), !.
is_type(Object, kind) :-
   kind(Object).
is_type(Object, List) :-
   list(List),
   member(Object, List).
is_type(Object, kind_of(Kind)) :-
   kind_of(Object, Kind).
is_type(Object, subkind_of(Kind)) :-
   subkind_of(Object, Kind).
is_type(Object, Kind) :-
   atom(Kind),
   is_a(Object, Kind).


%%%
%%% Properties
%%%

%% property_type(+Property, ?ObjectType, ?ValueType)
%  Property applies to objects of type ObjectType and its values are of type ValueType.

%% property_nondefault_value(?Object, ?Property, ?Value)
%  Object has this property value explicitly declared, rather than inferred.
property_nondefault_value(Object, Property, Value) :-
   declare_value(Object, Property, Value).

%% property_value(?Object, ?Property, ?Value)
%  Object has this value for this property.
property_value(Object, Property, Value) :-
   nonvar(Property),
   !,
   lookup_property_value(Object, Property, Value).
property_value(Object, Property, Value) :-
   is_a(Object, Kind),
   property_type(Property, Kind, _ValueType),
   lookup_property_value(Object, Property, Value).

unique_answer(Value, property_value(Object, Property, Value)) :-
   var(Value),
   nonvar(Object),
   nonvar(Property).

lookup_property_value(Object, Property, Value) :-
   declare_value(Object, Property, Value), !.
lookup_property_value(Object, Property, Value) :-
   is_a(Object, Kind),
   default_value(Kind, Property, Value), !.

%% valid_property_value(?Property, ?Value)
%  True if Value is a valid value for Property.
valid_property_value(P, V) :-
   property_type(P, _OType, VType),
   is_type(V, VType).

%%%
%%% Relations
%%%

%% relation_type(+Relation, ?ObjectType, ?RelatumType)
%  Relation relates objects of type ObjectType to objects of type RelatumType

%% related_nondefault(?Object, ?Relation, ?Relatum)
%  Object and Relatum are related by Relation through an explicit declaration.
related_nondefault(Object, Relation, Relatum) :-
   decendant_relation(D, Relation),
   declare_related(Object, D, Relatum).

%% related(?Object, ?Relation, ?Relatum)
%  Object and Relatum are related by Relation.
related(Object, Relation, Relatum) :-
   /brainwash/relations/Object/Relation/Relatum.
related(Object, Relation, Relatum) :-
   % This relation is canonically stored as its inverse
   inverse_relation(Relation, Inverse),
   related(Relatum, Inverse, Object).
related(Object, Relation, Relatum) :-
   nonvar(Relation),
   % This relation has no inverse or is the canonical form.
   \+ inverse_relation(Relation, _Inverse),
   decendant_relation(D, Relation),
   declare_related(Object, D, Relatum).
related(Object, Relation, Relatum) :-
   var(Relation),
   declare_related(Object, D, Relatum),
   decendant_relation(D, Relation).

decendant_relation(R, R).
decendant_relation(D, R) :-
   implies_relation(I, R),
   decendant_relation(D, I).

ancestor_relation(R,R).
ancestor_relation(A, R) :-
   implies_relation(R, I),
   ancestor_relation(A, I).
