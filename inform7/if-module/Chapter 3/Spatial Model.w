[PL::Spatial::] Spatial Model.

A plugin which constructs the fundamental spatial model used by
IF, to represent containment, support, carrying, wearing, and incorporation.

@h Definitions.

@ The "spatial model" is the aspect of the IF model world which represents
containment, support, carrying, wearing, and incorporation; say, a button
which is part of a shirt which is in a tumble-drier which is in a room
called the Laundry, where there's also a man carrying a box of washing
powder and wearing a dressing gown. That's quite a lot of concepts, but
note that it doesn't include the geographical model (directions, the map,
regions, and so on), which are formally separated from the spatial model
and are therefore managed by other plugins.

This is the largest and most complicated of the plugins. It has two basic
tasks: to infer the spatial structure from context and rather vague indications
of kinds and forms of containment; and then to compile an Inform 6
representation of the result, which is quite a messy business.

@ Every inference subject contains a pointer to its own unique copy of the
following structure, though it will only be relevant for instances of
"room" and "thing" -- the raw materials of our model world. The
fundamental spatial data we will keep for each object is its "progenitor",
which may be |NULL|, representing the object which immediately contains,
carries, wears, supports or incorporates it.

=
typedef struct spatial_data {
	/* fundamental spatial information about an object's location */
	struct instance *progenitor;
	struct parse_node *progenitor_set_at;
	int part_flag; /* is this a component part of something else? */
	int here_flag; /* was this declared simply as being "here"? */

	/* temporary storage needed when compiling spatial data to I6 code */
	struct instance *object_tree_parent; /* in/on/worn by/carried by tree structure */
	struct instance *object_tree_child;
	struct instance *object_tree_sibling;
	struct instance *incorp_tree_parent; /* part-of tree structure */
	struct instance *incorp_tree_child;
	struct instance *incorp_tree_sibling;
	int I6_definition_depth; /* i.e., how many arrows |->| appear in its I6 header */

	CLASS_DEFINITION
} spatial_data;

@ Here, first, are the special kinds of inference needed to store these vague
indications of spatial structure:

@d IS_ROOM_INF 50 /* is O a room? */
@d CONTAINS_THINGS_INF 51 /* does O contain things? */
@d PARENTAGE_INF 52 /* where is O located? */
@d PARENTAGE_HERE_INF 53 /* located vaguely as "here"? */
@d PARENTAGE_NOWHERE_INF 54 /* located vaguely as "nowhere"? */
@d PART_OF_INF 55 /* is O a part of another object? */

@ The Spatial plugin also needs to know about a considerable number of special
kinds and properties:

= (early code)
kind *K_room = NULL;
kind *K_thing = NULL;
kind *K_container = NULL;
kind *K_supporter = NULL;
kind *K_person = NULL;
kind *K_players_holdall = NULL;
property *P_initial_appearance = NULL;
property *P_wearable = NULL;
property *P_fixed_in_place = NULL;

property *P_component_parent = NULL;
property *P_component_child = NULL;
property *P_component_sibling = NULL;
property *P_worn = NULL;
property *P_mark_as_room = NULL;
property *P_mark_as_thing = NULL;
property *P_container = NULL;
property *P_supporter = NULL;
property *P_matching_key = NULL;

@ We will also need constants to talk about the inference subjects which
correspond to four of the special kinds -- ordinarily that would be redundant,
since you can get the subject as a function of the kind, but there's a tricky
timing issue to get around (see below).

= (early code)
inference_subject *infs_room = NULL;
inference_subject *infs_thing = NULL;
inference_subject *infs_supporter = NULL;
inference_subject *infs_person = NULL;

@h Initialisation.

=
void PL::Spatial::start(void) {
	PLUGIN_REGISTER(PLUGIN_NEW_BASE_KIND_NOTIFY, PL::Spatial::spatial_new_base_kind_notify);
	PLUGIN_REGISTER(PLUGIN_ACT_ON_SPECIAL_NPS, PL::Spatial::spatial_act_on_special_NPs);
	PLUGIN_REGISTER(PLUGIN_COMPLETE_MODEL, PL::Spatial::IF_complete_model);
	PLUGIN_REGISTER(PLUGIN_DEFAULT_APPEARANCE, PL::Spatial::spatial_default_appearance);
	PLUGIN_REGISTER(PLUGIN_INFERENCES_CONTRADICT, PL::Spatial::spatial_inferences_contradict);
	PLUGIN_REGISTER(PLUGIN_EXPLAIN_CONTRADICTION, PL::Spatial::spatial_explain_contradiction);
	PLUGIN_REGISTER(PLUGIN_LOG_INFERENCE_TYPE, PL::Spatial::spatial_log_inference_type);
	PLUGIN_REGISTER(PLUGIN_NAME_TO_EARLY_INFS, PL::Spatial::spatial_name_to_early_infs);
	PLUGIN_REGISTER(PLUGIN_NEW_SUBJECT_NOTIFY, PL::Spatial::spatial_new_subject_notify);
	PLUGIN_REGISTER(PLUGIN_NEW_PROPERTY_NOTIFY, PL::Spatial::spatial_new_property_notify);
	PLUGIN_REGISTER(PLUGIN_PARSE_COMPOSITE_NQS, PL::Spatial::spatial_parse_composite_NQs);
	PLUGIN_REGISTER(PLUGIN_SET_KIND_NOTIFY, PL::Spatial::spatial_set_kind_notify);
	PLUGIN_REGISTER(PLUGIN_SET_SUBKIND_NOTIFY, PL::Spatial::spatial_set_subkind_notify);
	PLUGIN_REGISTER(PLUGIN_ADD_TO_WORLD_INDEX, PL::Spatial::spatial_add_to_World_index);
	PLUGIN_REGISTER(PLUGIN_INTERVENE_IN_ASSERTION, PL::Spatial::spatial_intervene_in_assertion);
	@<Create early inference subjects@>;
}

@ In talking about some of the fundamental spatial domains we potentially have
a vicious circle, because
(a) we need fundamental kinds like "thing" and "room" in order to
specify the domains for built-in relations like "containment",
(b) we need built-in relations like "containment" in order to specify
the meanings of prepositional usages like "to be inside",
(c) we need to have defined usages like "to be inside" in order to
break up sentences in the parse tree and identify their primary verbs and
noun phrases, but
(d) we need a parse tree already in place before we can act on sentences
like "A room is a kind of object." which create the fundamental kinds.

We break the deadlock at (a) by specifying the domains of the built-in
relations using inference subject structures created in advance of the
kinds they will one day infer about. These amount to promisory notes that
we will make them correspond to the actual kinds later on, at some point
after stage (d) when they exist.

@<Create early inference subjects@> =
	infs_room = InferenceSubjects::new(global_constants,
		FUND_SUB, NULL_GENERAL_POINTER, LIKELY_CE);
	infs_thing = InferenceSubjects::new(global_constants,
		FUND_SUB, NULL_GENERAL_POINTER, LIKELY_CE);
	infs_supporter = InferenceSubjects::new(global_constants,
		FUND_SUB, NULL_GENERAL_POINTER, LIKELY_CE);
	infs_person = InferenceSubjects::new(global_constants,
		FUND_SUB, NULL_GENERAL_POINTER, LIKELY_CE);

@ And this is where those IOUs are redeemed. What happens is that, ordinarily,
the machinery creating objects (and kinds) will allocate a new inference
structure for each object, but it first invites plugins to choose an existing
one instead. (The INFS structure is rewritten, but the important thing is that
pointers to it remain consistent and valid.)

=
int PL::Spatial::spatial_name_to_early_infs(wording W, inference_subject **infs) {
	if (<notable-spatial-kinds>(W)) {
		switch (<<r>>) {
			case 0: if (K_room == NULL) *infs = infs_room; break;
			case 1: if (K_thing == NULL) *infs = infs_thing; break;
			/* container isn't an early case, surprisingly */
			case 3: if (K_supporter == NULL) *infs = infs_supporter; break;
			case 4: if (K_person == NULL) *infs = infs_person; break;
		}
	}
	return FALSE;
}

@ Here we initialise the data used by Spatial for each object:

=
spatial_data *PL::Spatial::new_data(inference_subject *subj) {
	spatial_data *sd = CREATE(spatial_data);
	sd->progenitor = NULL; sd->progenitor_set_at = NULL; sd->part_flag = FALSE;
	sd->object_tree_parent = NULL; sd->object_tree_child = NULL; sd->object_tree_sibling = NULL;
	sd->incorp_tree_child = NULL; sd->incorp_tree_sibling = NULL; sd->incorp_tree_parent = NULL;
	sd->I6_definition_depth = 0;
	sd->here_flag = FALSE;
	return sd;
}

@h Special inferences.
Four of these are quite simple inferences, but |PARENTAGE_INF| stores the
object to which a spatial relationship is being inferred; and this means that
multiple |PARENTAGE_INF|s can contradict each other.

=
int PL::Spatial::spatial_log_inference_type(int it) {
	switch(it) {
		case CONTAINS_THINGS_INF: LOG("CONTAINS_THINGS_INF"); return TRUE;
		case IS_ROOM_INF: LOG("IS_ROOM_INF"); return TRUE;
		case PARENTAGE_HERE_INF: LOG("PARENTAGE_HERE_INF"); return TRUE;
		case PARENTAGE_NOWHERE_INF: LOG("PARENTAGE_NOWHERE_INF"); return TRUE;
		case PARENTAGE_INF: LOG("PARENTAGE_INF"); return TRUE;
		case PART_OF_INF: LOG("PART_OF_INF"); return TRUE;
	}
	return FALSE;
}

int PL::Spatial::spatial_inferences_contradict(inference *A, inference *B, int similarity) {
	if ((World::Inferences::get_inference_type(A) == PARENTAGE_INF) &&
		(World::Inferences::get_reference_as_object(A) !=
			World::Inferences::get_reference_as_object(B)))
		return TRUE;
	return FALSE;
}

int PL::Spatial::spatial_explain_contradiction(inference *A, inference *B, int similarity,
	inference_subject *subj) {
	if ((World::Inferences::get_inference_type(A) == PARENTAGE_INF) &&
		(World::Inferences::get_reference_as_object(A) !=
			World::Inferences::get_reference_as_object(B))) {
		Problems::quote_source(1, World::Inferences::where_inferred(A));
		Problems::quote_source(2, World::Inferences::where_inferred(B));
		Problems::quote_subject(3, subj);
		Problems::quote_object(4, World::Inferences::get_reference_as_object(A));
		Problems::quote_object(5, World::Inferences::get_reference_as_object(B));
		StandardProblems::handmade_problem(Task::syntax_tree(), _p_(PM_SpatialContradiction));
		Problems::issue_problem_segment(
			"You wrote %1, but also %2: that seems to be saying that the same "
			"object (%3) must be in two different places (%4 and %5). This "
			"looks like a contradiction. %P"
			"This sometimes happens as a result of a sentence like 'Every person "
			"carries a bag', when Inform doesn't know 'bag' as the name of any "
			"kind - so that it makes only a single thing called 'bag', and then "
			"the sentence looks as if it says everyone is carrying the same bag.");
		Problems::issue_problem_end();
		return TRUE;
	}
	return FALSE;
}

@h Special kinds.
These are kind names to do with spatial layout which Inform provides special
support for; it recognises the Englishs name when defined by the Standard
Rules. (So there is no need to translate this to other languages.)

=
<notable-spatial-kinds> ::=
	room |
	thing |
	container |
	supporter |
	person |
	player's holdall

@ =
int PL::Spatial::spatial_new_base_kind_notify(kind *new_base, text_stream *name, wording W) {
	if (<notable-spatial-kinds>(W)) {
		switch (<<r>>) {
			case 0: K_room = new_base; return TRUE;
			case 1: K_thing = new_base; return TRUE;
			case 2: K_container = new_base; return TRUE;
			case 3: K_supporter = new_base; return TRUE;
			case 4: K_person = new_base; return TRUE;
			case 5: K_players_holdall = new_base; return TRUE;
		}
	}
	return FALSE;
}

int PL::Spatial::spatial_new_subject_notify(inference_subject *subj) {
	CREATE_PF_DATA(spatial, subj, PL::Spatial::new_data);
	return FALSE;
}

@ When the rest of Inform makes something a room, for instance in response to
an explicit sentence like "The Hall of Mirrors is a room.", we take notice;
if it turns out to be news, we infer |IS_ROOM_INF| with certainty.

=
int PL::Spatial::spatial_set_kind_notify(instance *I, kind *k) {
	kind *kw = Instances::to_kind(I);
	if ((!(Kinds::Compare::le(kw, K_room))) &&
		(Kinds::Compare::le(k, K_room)))
		World::Inferences::draw(IS_ROOM_INF, Instances::as_subject(I), CERTAIN_CE,
			NULL, NULL);
	return FALSE;
}

@ Nothing in the core Inform language prevents room from being made a kind
of vehicle, and so on, but this would cause mayhem in the model world. So:

=
int PL::Spatial::spatial_set_subkind_notify(kind *sub, kind *super) {
	if ((sub == K_thing) && (super != K_object)) {
		if (problem_count == 0)
			StandardProblems::sentence_problem(Task::syntax_tree(), _p_(PM_ThingAdrift),
				"'thing' is not allowed to be a kind of anything (other than "
				"'object')",
				"because it's too fundamental to the way Inform uses rooms "
				"and things to model the physical world.");
		return TRUE;
	}
	if ((sub == K_room) && (super != K_object)) {
		if (problem_count == 0)
			StandardProblems::sentence_problem(Task::syntax_tree(), _p_(PM_RoomAdrift),
				"'room' is not allowed to be a kind of anything (other than "
				"'object')",
				"because it's too fundamental to the way Inform uses rooms "
				"and things to model the physical world.");
		return TRUE;
	}
	if (((sub == K_container) && (super == K_supporter)) ||
		((sub == K_supporter) && (super == K_container))) {
		if (problem_count == 0)
			StandardProblems::sentence_problem(Task::syntax_tree(), _p_(PM_ContainerAdrift),
				"'container' and 'supporter' are not allowed to be kinds "
				"of each other",
				"because they're too fundamental to the way Inform models the "
				"physical world. Both are kinds of 'thing', but they are "
				"different, and no object is allowed to belong to both at once.");
		return TRUE;
	}
	return FALSE;
}

@ This tests whether an object is an instance of "room":

=
int PL::Spatial::object_is_a_room(instance *I) {
	if ((Plugins::Manage::plugged_in(spatial_plugin)) && (K_room) && (I) &&
		(Instances::of_kind(I, K_room)))
		return TRUE;
	return FALSE;
}

@ This is where we give Inform the numbers it needs to write the "a world
with 5 rooms and 27 things"-style text in a successful report on its run.

=
void PL::Spatial::get_world_size(int *rooms, int *things) {
	instance *I;
	*rooms = 0; *things = 0;
	LOOP_OVER_INSTANCES(I, K_room) (*rooms)++;
	LOOP_OVER_INSTANCES(I, K_thing) (*things)++;
}

@h Special properties.
These are property names to do with spatial layout which Inform provides
special support for; it recognises the English names when they are defined by
the Standard Rules. (So there is no need to translate this to other languages.)

"Matching key" has to appear in here because it both has a traditional I6
name and is used as relation storage. If we didn't care about it being
called |with_key| in the I6 source code, we wouldn't need to do anything
special with it at all.

=
<notable-spatial-properties> ::=
	initial appearance |
	wearable |
	fixed in place |
	matching key

@ =
int PL::Spatial::spatial_new_property_notify(property *prn) {
	if (<notable-spatial-properties>(prn->name)) {
		switch (<<r>>) {
			case 0: P_initial_appearance = prn; break;
			case 1: P_wearable = prn; break;
			case 2: P_fixed_in_place = prn; break;
			case 3: P_matching_key = prn;
				Properties::set_translation(P_matching_key, L"with_key");
				break;
		}
	}
	return FALSE;
}

@h Default appearances.
Spatial gets to decide here what raw text following a new object will be
taken to mean: for scenery it will be the "description" (i.e., the text
produced on examining), for any other thing it will be the "initial
appearance".

=
int PL::Spatial::spatial_default_appearance(inference_subject *infs, parse_node *txt) {
	if (InferenceSubjects::is_within(infs, Kinds::Knowledge::as_subject(K_object))) {
		property *set_prn = P_description;
		if (InferenceSubjects::is_within(infs, Kinds::Knowledge::as_subject(K_thing))) {
			instance *I = InferenceSubjects::as_object_instance(infs);
			if ((I) && (PL::Backdrops::object_is_scenery(I))) {
				inference *inf;
				KNOWLEDGE_LOOP(inf, infs, PROPERTY_INF) {
					property *prn = World::Inferences::get_property(inf);
					if (((prn) && (World::Inferences::get_certainty(inf) > 0)) &&
						(prn == P_description)) {
						@<Produce a problem for doubly described scenery@>;
						return TRUE;
					}
				}
			} else set_prn = P_initial_appearance;
		}
		Properties::Valued::assert(set_prn, infs, txt, CERTAIN_CE);
		return TRUE;
	}
	return FALSE;
}

@ A lone string as a sentence is a description for a room, but an initial
description for an object. Only now can we know which, since we have only
just decided whether |I| is a room or not. We therefore draw the necessary
inference.

@<Produce a problem for doubly described scenery@> =
	StandardProblems::object_problem(_p_(PM_SceneryDoublyDescribed),
		I,
		"is scenery, which means that it cannot sensibly have any 'initial "
		"appearance' property - being scenery, it isn't announced when the "
		"player first sees it. That means the quoted text about it has to "
		"be read as its 'description' instead, seen when the player examines "
		"it. But the source text writes out its description, too",
		"which means we have a subtle little contradiction here.");

@h Composite noun-quantifiers.
"Nothing" is conspicuously absent from the possibilities below. It gets
special treatment elsewhere since it can also double as a value (the "not
an object" pseudo-value).

=
<spatial-specifying-nouns> ::=
	_something/anything *** | 	            ==> { -, K_thing }
	_somewhere/anywhere *** | 	            ==> { -, K_room }
	_someone/anyone/somebody/anybody *** | 	==> { -, K_person }
	_everything *** |                       ==> { -, K_thing, <<quantifier:q>> = for_all_quantifier }
	_everywhere *** |                       ==> { -, K_room, <<quantifier:q>> = for_all_quantifier }
	_everyone/everybody *** |               ==> { -, K_person, <<quantifier:q>> = for_all_quantifier }
	_nowhere *** |                          ==> { -, K_room, <<quantifier:q>> = not_exists_quantifier }
	_nobody/no-one *** |                    ==> { -, K_person, <<quantifier:q>> = not_exists_quantifier }
	_no _one ***                            ==> { -, K_person, <<quantifier:q>> = not_exists_quantifier }

@ Words like "something" or "everywhere" combine a common noun -- thing,
and implicitly room -- with a determiner -- one thing, all rooms. When we
detect them, we set both |quantifier_used| and |some_kind| appropriately.
None can be recognised if the basic kinds are not created yet, which we
check for by inspecting |K_thing|. (Note that the S-parser may indeed be
asked to parse "something" before this point, as when it scans the
domains of adjective definitions, but that it's okay that it produces a
null result.)

With the "some-" words, no quantifier is set because the meaning here is
the |exists_quantifier|. Since this is the default behaviour for
unquantified descriptions anyway -- "a door is in the Great Hall" means
that such a door exists -- we needn't set the variable.

=
int PL::Spatial::spatial_parse_composite_NQs(wording *W, wording *DW,
	quantifier **quant, kind **some_kind) {
	if (K_thing) {
		<<quantifier:q>> = NULL;
		if (<spatial-specifying-nouns>(*W)) {
			*W = Wordings::from(*W, Wordings::first_wn(GET_RW(<spatial-specifying-nouns>, 1)));
			*quant = <<quantifier:q>>; *some_kind = <<rp>>;
			return TRUE;
		}
	}
	return FALSE;
}

@h Nowhere.
This means the same as "nothing", in a noun context, but we annotate a parse
node using this wording in order to produce better problem messages if need be.

=
<notable-spatial-noun-phrases> ::=
	nowhere

@ =
int PL::Spatial::spatial_act_on_special_NPs(parse_node *p) {
	if ((<notable-spatial-noun-phrases>(Node::get_text(p))) &&
		(Word::unexpectedly_upper_case(Wordings::first_wn(Node::get_text(p))) == FALSE) &&
		(K_room)) {
		Assertions::Refiner::noun_from_value(p, Rvalues::new_nothing_object_constant());
		Annotations::write_int(p, nowhere_ANNOT, TRUE);
		return TRUE;
	}
	return FALSE;
}

@ Now in fact this often does get picked up:

=
int PL::Spatial::spatial_intervene_in_assertion(parse_node *px, parse_node *py) {
	if (Annotations::read_int(py, nowhere_ANNOT)) {
		inference_subject *left_subject = Node::get_subject(px);
		if (left_subject) {
			if (InferenceSubjects::domain(left_subject))
				StandardProblems::subject_problem_at_sentence(_p_(PM_KindNowhere),
					left_subject,
					"seems to be said to be 'nowhere' in some way",
					"which doesn't make sense. An individual thing can be 'nowhere', "
					"but here we're talking about a whole kind, and it's not allowed "
					"to talk about general locations of a whole kind of things at once.");
			else Calculus::Propositions::Assert::assert_true_about(
				Calculus::Propositions::Abstract::to_put_nowhere(), left_subject, prevailing_mood);
			return TRUE;
		}
	}
	return FALSE;
}

@h Here.
A sentence like "The sonic screwdriver is here." is not copular, but instead
expresses a relationship -- "here" is not a value but a relation to an
unstated object. That object is the room we're currently talking about, which
sounds easy to work out, but isn't: we don't yet know which of the objects
being talked about will eventually turn out to be rooms. As a result, "here"
needs delicate handling, and its own inference type.

The fact that rooms cannot be "here" is useful, because it means Inform can
with certainty read

>> The washing machine is here. The shirt is in the machine.

as creating a container called "washing machine", not a room.

@ =
void PL::Spatial::infer_presence_here(instance *I) {
	inference_subject *infs = Instances::as_subject(I);
	inference *inf;
	POSITIVE_KNOWLEDGE_LOOP(inf, infs, PARENTAGE_HERE_INF) {
		StandardProblems::contradiction_problem(_p_(PM_DuplicateHere),
			World::Inferences::where_inferred(inf),
			current_sentence,
			I,
			"can only be said to be 'here' once",
			"in a single assertion sentence. This avoids potential confusion, "
			"since 'here' can mean different things in different sentences.");
	}

	World::Inferences::draw(PARENTAGE_HERE_INF, infs, CERTAIN_CE,
		Assertions::Traverse::get_current_subject(), NULL);
	World::Inferences::draw(IS_ROOM_INF, infs, IMPOSSIBLE_CE, NULL, NULL);
}

@ Similarly:

=
void PL::Spatial::infer_presence_nowhere(instance *I) {
	World::Inferences::draw(PARENTAGE_NOWHERE_INF,
		Instances::as_subject(I), CERTAIN_CE, NULL, NULL);
	World::Inferences::draw(IS_ROOM_INF, Instances::as_subject(I), IMPOSSIBLE_CE,
		NULL, NULL);
}

@h Completing the model, stages I and II.
That's enough preliminaries; time to get on with adding a sense of space
to the model world.

=
int PL::Spatial::IF_complete_model(int stage) {
	switch(stage) {
		case 1: PL::Spatial::spatial_stage_I(); break;
		case 2: PL::Spatial::spatial_stage_II(); break;
		case 3: PL::Spatial::spatial_stage_III(); break;
		case 4: PL::Spatial::spatial_stage_IV(); break;
	}
	return FALSE;
}

@ Recall that as we begin stage I of model creation, all objects are, of
course, created, and they have kinds associated with them if the source
text has said explicitly what kind they have: but that is not good enough.
It often happens that the source implicitly specifies a kind, and we need
to take note. If X is in Y, then Y might be a room, or a region, or a
container, and we might need to look at other sentences -- say, establishing
that Y is the destination of a map connection -- to see which.

=
int PL::Spatial::spatial_stage_I(void) {
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I)
		@<Perform kind determination for this object@>;
	return FALSE;
}

@ Our main problem in what follows is caused by "in" being so ambiguous,
or perhaps it might be said that the real problem is that we choose to
distinguish between rooms and containers on a world-modelling level -- when it
could well be argued that they are linguistically the same thing.

It means that Inform is often reading code such as:

>> The croquet ball is in the Boxed Set.

and not being sure whether "Boxed Set" is a container or a room.

In the following determination, we use two sources of information. One is explicit
data given by the source text or unambiguously implied in it, like so --

>> The Boxed Set is a container. The spoon is on the low table.

which tell us the Boxed Set is certainly a container and the table certainly
a supporter. This information about an object is the "designer choice" about
its kind.

The other source of information comes from less definite sentences using words
like "in", and from the spatial context in which the object appears. This
is the "geography choice" for its kind.

@<Perform kind determination for this object@> =
	current_sentence = Instances::get_creating_sentence(I);

	kind *designers_choice = NULL;
	@<Determine the designer choice@>;

	kind *geography_choice = NULL;
	inference *geography_inference = NULL;
	int geography_certainty = UNKNOWN_CE;
	@<Determine the geography choice@>;

	if ((geography_choice) &&
		(Kinds::Compare::eq(geography_choice, designers_choice) == FALSE))
		@<Attempt to reconcile the two choices@>;

	if (Kinds::Compare::eq(Instances::to_kind(I), K_object))
		Calculus::Propositions::Abstract::assert_kind_of_object(I, K_thing);

@ By this point, any explicit information is reflected in the hierarchy of
kinds. We look out for four specialised kinds of thing, but failing that,
we simply take its broadest kind -- usually "thing", "room", "direction"
or "region".

@<Determine the designer choice@> =
	kind *f = NULL;
	inference_subject *infs;
	for (infs = Kinds::Knowledge::as_subject(Instances::to_kind(I));
		infs; infs = InferenceSubjects::narrowest_broader_subject(infs)) {
		kind *K = InferenceSubjects::as_kind(infs);
		if (Kinds::Compare::lt(K, K_object)) {
			f = K;
			if ((Kinds::Compare::eq(f, K_container)) ||
				(Kinds::Compare::eq(f, K_supporter)) ||
				(Kinds::Compare::eq(f, K_door)) ||
				(Kinds::Compare::eq(f, K_person)))
				designers_choice = f;
		}
	}
	if (designers_choice == NULL) designers_choice = f;

@ If there is any positive information that this is a room, that's the
geography choice; otherwise it's whichever of room or container is more
probably suggested by inferences.

@<Determine the geography choice@> =
	inference *inf;
	KNOWLEDGE_LOOP(inf, Instances::as_subject(I), CONTAINS_THINGS_INF)
		if (World::Inferences::get_certainty(inf) > geography_certainty) {
			geography_choice = K_container;
			geography_certainty = World::Inferences::get_certainty(inf);
			geography_inference = inf;
		}
	KNOWLEDGE_LOOP(inf, Instances::as_subject(I), IS_ROOM_INF)
		if ((World::Inferences::get_certainty(inf) > UNKNOWN_CE) ||
			(World::Inferences::get_certainty(inf) > geography_certainty)) {
			geography_choice = K_room;
			geography_certainty = World::Inferences::get_certainty(inf);
			geography_inference = inf;
		}

@ Since the designer choice is the one currently in force, we have basically
three choices here: impose the geography choice instead; do nothing; or issue
a problem message. The case where we do nothing is if geography suggests
something is a room, when it's actually a door: this is because sentences
like "East is the Marble Portal" can suggest the "Marble Portal" is a room
when it's legitimately a door.

@<Attempt to reconcile the two choices@> =
	parse_node *sentence_setting_kind = Instances::get_kind_set_sentence(I);
	if ((designers_choice == NULL) ||
		((geography_certainty == CERTAIN_CE) &&
			(Kinds::Compare::le(geography_choice, designers_choice))))
		@<Accept the geography choice, since it only refines what we already know@>
	else if ((geography_certainty == CERTAIN_CE) &&
			(!((Kinds::Compare::eq(designers_choice, K_door)) &&
				(Kinds::Compare::eq(geography_choice, K_room)))))
		@<Issue a problem message, since the choices are irreconcilable@>;

@<Accept the geography choice, since it only refines what we already know@> =
	LOGIF(KIND_CHANGES, "Accepting geography choice of kind of $O as $u\n",
		I, geography_choice);
	Calculus::Propositions::Abstract::assert_kind_of_object(I, geography_choice);

@<Issue a problem message, since the choices are irreconcilable@> =
	LOG("Choices: designer $u, geography $u.\n", designers_choice, geography_choice);
	parse_node *decider = Instances::get_creating_sentence(I);
	if (sentence_setting_kind) decider = sentence_setting_kind;
	if (Kinds::Compare::eq(designers_choice, K_person))
		@<Issue a problem message for implied containment by a person@>
	else if ((Kinds::Compare::eq(designers_choice, K_supporter)) &&
				(Kinds::Compare::eq(geography_choice, K_container)))
		@<Issue a problem message for simultaneous containment and support@>
	else
		@<Issue a more generic problem message for irreconcilable kinds@>;

@<Issue a problem message for implied containment by a person@> =
	StandardProblems::contradiction_problem(_p_(PM_PersonContaining),
		sentence_setting_kind,
		World::Inferences::where_inferred(geography_inference), I,
		"cannot contain or support things like something inanimate",
		"which is what you are implying. Instead, people must carry or wear them: "
		"so 'The briefcase is in Daphne.' is disallowed, but 'The briefcase is "
		"carried by Daphne.' is fine, or indeed 'Daphne carries the briefcase.'");

@ A notorious problem message for a notorious limitation of the traditional
Inform spatial model:

@<Issue a problem message for simultaneous containment and support@> =
	StandardProblems::contradiction_problem(_p_(PM_CantContainAndSupport),
		decider, World::Inferences::where_inferred(geography_inference), I,
		"cannot both contain things and support things",
		"which is what you're implying here. If you need both, the easiest way is "
		"to make it either a supporter with a container attached or vice versa. "
		"For instance: 'A desk is here. On the desk is a newspaper. An openable "
		"container called the drawer is part of the desk. In the drawer is a "
		"stapler.'");

@<Issue a more generic problem message for irreconcilable kinds@> =
	StandardProblems::contradiction_problem(_p_(PM_BothRoomAndSupporter),
		decider,
		World::Inferences::where_inferred(geography_inference), I,
		"would need to have two different and incompatible kinds to make both "
		"sentences true",
		"and this is a contradiction.");

@ Stage II at last. Now the kinds are all known, and it's time to work out
the spatial arrangements. Inform's spatial model assigns every instance object
a unique "progenitor", which may be |NULL|, representing the object which
immediately contains, carries, wears, supports or incorporates it.

Clearly if we know every object's progenitor, then we know the whole spatial
layout -- it's all just elaboration from there. (See Stage III below.) But
since other plugins can decide on this, not just Spatial, we had better
provide access routines to read and write:

=
instance *PL::Spatial::progenitor(instance *I) {
	if (I == NULL) return NULL;
	if (Plugins::Manage::plugged_in(spatial_plugin) == FALSE) return NULL;
	return PF_I(spatial, I)->progenitor;
}

void PL::Spatial::set_progenitor(instance *of, instance *to, inference *reason) {
	if (Plugins::Manage::plugged_in(spatial_plugin) == FALSE)
		internal_error("spatial plugin inactive");
	if (to == NULL) internal_error("set progenitor of nothing");
	PF_I(spatial, of)->progenitor = to;
	PF_I(spatial, of)->progenitor_set_at =
		(reason)?World::Inferences::where_inferred(reason):NULL;
}

@ This is used for error recovery only.

=
void PL::Spatial::void_progenitor(instance *of) {
	if (Plugins::Manage::plugged_in(spatial_plugin) == FALSE)
		internal_error("spatial plugin inactive");
	PF_I(spatial, of)->progenitor = NULL;
	PF_I(spatial, of)->progenitor_set_at = NULL;
}

@ We need to establish what the rooms are before we worry about objects which
are "here"; rooms are never "here", so there's no circularity in that,
and we solve this problem by determining the kind of non-here objects before
the kind of here-objects.

=
int PL::Spatial::spatial_stage_II(void) {
	@<Set the here flag for all those objects whose parentage is only thus known@>;
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I)
		if (PF_I(spatial, I)->here_flag == FALSE)
			@<Position this object spatially@>;
	LOOP_OVER_OBJECT_INSTANCES(I)
		if (PF_I(spatial, I)->here_flag)
			@<Position this object spatially@>;
	@<Issue problem messages if non-physical objects are spatially enclosed@>;
	return FALSE;
}

@<Set the here flag for all those objects whose parentage is only thus known@> =
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		PF_I(spatial, I)->here_flag = FALSE;
		inference *inf;
		POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(I), PARENTAGE_HERE_INF)
			PF_I(spatial, I)->here_flag = TRUE;
	}

@<Issue problem messages if non-physical objects are spatially enclosed@> =
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		if ((PL::Spatial::progenitor(I)) &&
			(Instances::of_kind(I, K_thing) == FALSE) &&
			(Instances::of_kind(I, K_room) == FALSE) &&
			(PL::Regions::object_is_a_region(I) == FALSE)) {
			Problems::quote_source(1, Instances::get_creating_sentence(I));
			Problems::quote_object(2, I);
			Problems::quote_object(3, PL::Spatial::progenitor(I));
			Problems::quote_kind(4, Instances::to_kind(I));
			StandardProblems::handmade_problem(Task::syntax_tree(), _p_(PM_NonThingInModel));
			Problems::issue_problem_segment(
				"In the sentence %1, you create an object '%2' which you then seem "
				"to place in or on or as part of '%3', but the kind of '%2' is %4. "
				"Since %4 is not a kind of thing, it follows that %2 is not a thing, "
				"so it doesn't represent something physical and can't be put in spatial "
				"relationships like this. (For the same reason that you can't put "
				"'southeast', the direction, inside a kitchen cupboard.)");
			Problems::issue_problem_end();
		}
	}

@ At last we come to it: determining the progenitor, and part-flag, for the
object under investigation.

@<Position this object spatially@> =
	inference *parent_setting_inference = NULL;
	@<Find the inference which will decide the progenitor@>;
	if (parent_setting_inference) {
		instance *whereabouts =
			World::Inferences::get_reference_as_object(parent_setting_inference);
		if (PF_I(spatial, I)->here_flag) @<Find the whereabouts of something here@>;
		if (whereabouts) {
			PL::Spatial::set_progenitor(I, whereabouts, parent_setting_inference);
			LOGIF(OBJECT_TREE, "Progenitor of $O is $O\n", I, whereabouts);
		}
	}
	@<Determine whether the object in question is a component part@>;

@<Find the inference which will decide the progenitor@> =
	inference *inf;
	POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(I), PARENTAGE_NOWHERE_INF)
		@<Make this the determining inference@>;
	POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(I), PARENTAGE_HERE_INF)
		@<Make this the determining inference@>;
	POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(I), PARENTAGE_INF)
		@<Make this the determining inference@>;

@<Make this the determining inference@> =
	if (parent_setting_inference) {
		StandardProblems::contradiction_problem(_p_(PM_DuplicateParentage),
			World::Inferences::where_inferred(parent_setting_inference),
			World::Inferences::where_inferred(inf),
			I,
			"can only be given its position once",
			"in a single assertion sentence.");
	}
	parent_setting_inference = inf;

@<Find the whereabouts of something here@> =
	if (PL::Spatial::object_is_a_room(whereabouts) == FALSE) whereabouts = NULL;
	if (whereabouts == NULL) {
		parse_node *here_sentence =
			World::Inferences::where_inferred(parent_setting_inference);
		@<Set the whereabouts to the last discussed room prior to this inference being drawn@>;
		if (whereabouts == NULL) {
			current_sentence = here_sentence;
			StandardProblems::object_problem_at_sentence(_p_(PM_NoHere),
				I,
				"was described as being 'here', and there doesn't seem to be any "
				"location being talked about at this point in the source text",
				"so there's nowhere you can call 'here'.");
		}
	}

@ This runs through the source text from the beginning up to the "here"
sentence, setting |whereabouts| to any rooms it finds along the way, so that
when it finishes this will be set to the most recently mentioned.

@<Set the whereabouts to the last discussed room prior to this inference being drawn@> =
	SyntaxTree::traverse_up_to_ip(Task::syntax_tree(), here_sentence,
		PL::Spatial::seek_room, (void **) &whereabouts);

@<Determine whether the object in question is a component part@> =
	inference *inf;
	POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(I), PART_OF_INF) {
		if ((PL::Spatial::object_is_a_room(I)) || (PL::Map::object_is_a_door(I))) {
			StandardProblems::object_problem(_p_(PM_RoomOrDoorAsPart),
				I,
				"was set up as being part of something else, which doors and rooms "
				"are not allowed to be",
				"because they are part of the fixed map of the world - if they were "
				"parts of something else, they might move around. (Of course, it's "
				"easy to make a door look as if it's part of something to the player - "
				"describing it as part of a wall, or bulkhead, or cottage, say - "
				"and if there really is an entrance that needs to move around - say, "
				"the hatchway on a tank - it's probably best to make it an enterable "
				"container.)");
		}
		PF_I(spatial, I)->part_flag = TRUE;
	}

@ =
void PL::Spatial::seek_room(parse_node *sent, void **v_I) {
	instance **I = (instance **) v_I;
	inference_subject *isub = Node::get_interpretation_of_subject(sent);
	instance *sub = InferenceSubjects::as_object_instance(isub);
	if (PL::Spatial::object_is_a_room(sub)) *I = sub;
}

@h Completing the model, stages III and IV.
By the beginning of Stage III, the progenitor of every object is known, and
so is whether it is a part. It's time to start work on compiling the I6
representation of all this, but unfortunately that will need to be quite a
bit more complicated. So we're going to do this in two stages, the first
of which is to construct a pair of object trees as an intermediate state.

We have a main object tree, in fact a forest (i.e., it's probably disconnected),
to represent containment, support, carrying and wearing; and a secondary tree
for incorporation only. In this source code, we'll use the language of family
trees (parent, children, siblings) rather than horticulture (branches, leaves,
grafting). Both trees must be well-founded, and must be such that each object
is the parent of all its children. But the trees aren't independent of each
other: an object is not allowed to have a parent in both trees at once.
If it has a parent in either one, then that parent is required to be its progenitor.

@ The following logs the more interesting tree:

=
void PL::Spatial::log_object_tree(void) {
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I)
		if (PF_I(spatial, I)->object_tree_parent == NULL)
			PL::Spatial::log_object_tree_recursively(I, 0);
}

void PL::Spatial::log_object_tree_recursively(instance *I, int depth) {
	int i = depth;
	while (i>0) { LOG("  "); i--; }
	LOG("$O\n", I);
	if (PF_I(spatial, I)->object_tree_child)
		PL::Spatial::log_object_tree_recursively(PF_I(spatial, I)->object_tree_child, depth+1);
	if (PF_I(spatial, I)->object_tree_sibling)
		PL::Spatial::log_object_tree_recursively(PF_I(spatial, I)->object_tree_sibling, depth);
}

@ The initial state of both trees is total disconnection. They are then produced
using only two operations, which we'll call "adoption" and "parting".

The adoption routine is the equivalent of the Inform 6 statement "move
X to Y", and moves X and its children to become the youngest child of Y.
The tree is grown entirely from its root by repeated use of this one operation.

=
void PL::Spatial::adopt_object(instance *orphan, instance *foster) {
	LOGIF(OBJECT_TREE, "Grafting $O to be child of $O\n", orphan, foster);
	if (orphan == NULL) internal_error("orphan is null in adoption");
	if (foster == NULL) internal_error("foster is null in adoption");

	instance *former_parent = PF_I(spatial, orphan)->object_tree_parent;
	if (former_parent) @<Remove the object from the main object tree@>;
	@<Adopt the object into the main object tree@>;
}

@ "Parting" is the operation of being removed from the main tree and placed
in the incorporation tree instead, but with the same parent.

=
void PL::Spatial::part_object(instance *orphan) {
	LOGIF(OBJECT_TREE, "Parting $O\n", orphan);
	if (orphan == NULL) internal_error("new part is null in parting");

	instance *former_parent = PF_I(spatial, orphan)->object_tree_parent;
	if (former_parent == NULL) internal_error("new part is without parent");

	@<Remove the object from the main object tree@>;
	@<Adopt the object into the incorporation tree@>;
}

@<Remove the object from the main object tree@> =
	if (PF_I(spatial, former_parent)->object_tree_child == orphan) {
		PF_I(spatial, former_parent)->object_tree_child =
			PF_I(spatial, orphan)->object_tree_sibling;
	} else {
		instance *elder = PF_I(spatial, former_parent)->object_tree_child;
		while (elder) {
			if (PF_I(spatial, elder)->object_tree_sibling == orphan)
				PF_I(spatial, elder)->object_tree_sibling =
					PF_I(spatial, orphan)->object_tree_sibling;
			elder = PF_I(spatial, elder)->object_tree_sibling;
		}
	}
	PF_I(spatial, orphan)->object_tree_parent = NULL;
	PF_I(spatial, orphan)->object_tree_sibling = NULL;

@<Adopt the object into the main object tree@> =
	if (PF_I(spatial, foster)->object_tree_child == NULL) {
		PF_I(spatial, foster)->object_tree_child = orphan;
	} else {
		instance *elder = PF_I(spatial, foster)->object_tree_child;
		while (PF_I(spatial, elder)->object_tree_sibling)
			elder = PF_I(spatial, elder)->object_tree_sibling;
		PF_I(spatial, elder)->object_tree_sibling = orphan;
	}
	PF_I(spatial, orphan)->object_tree_parent = foster;

@<Adopt the object into the incorporation tree@> =
	if (PF_I(spatial, former_parent)->incorp_tree_child == NULL) {
		PF_I(spatial, former_parent)->incorp_tree_child = orphan;
	} else {
		instance *existing_part = PF_I(spatial, former_parent)->incorp_tree_child;
		while (PF_I(spatial, existing_part)->incorp_tree_sibling)
			existing_part = PF_I(spatial, existing_part)->incorp_tree_sibling;
		PF_I(spatial, existing_part)->incorp_tree_sibling = orphan;
	}
	PF_I(spatial, orphan)->incorp_tree_parent = former_parent;

@ What will we use the trees for? Well, one use is to tell other plugins
which depend on Spatial whether or not one object spatially contains another:

=
int PL::Spatial::encloses(instance *I1, instance *I2) {
	while (I1) {
		I1 = PL::Spatial::progenitor(I1);
		if (I1 == I2) return TRUE;
	}
	return FALSE;
}

@ But the main use for the trees is, as noted above, to form a convenient
intermediate state between the mass of progenitor data and the messy Inform 6
code it turns into. Here goes:

=
int PL::Spatial::spatial_stage_III(void) {
	int well_founded = TRUE;
	@<Define the Rucksack Class constant@>;
	@<Check the well-foundedness of the hierarchy of the set of progenitors@>;
	if (well_founded) @<Expand the progenitor data into the two object trees@>;
	@<Assert the portability of any item carried or supported by a person@>;
	@<Assert I6-level properties to express the spatial structure@>;
	@<Set up the compilation sequence so that it traverses the main object tree@>;
	if (Log::aspect_switched_on(OBJECT_TREE_DA)) PL::Spatial::log_object_tree();
	return FALSE;
}

@ To enable the use of player's holdalls, we must declare a constant
|RUCKSACK_CLASS| to tell some code in the template layer to use possessions
with this I6 class as the rucksack pro tem. This is all a bit of a hack, to retrofit
a degree of generality onto the original I6 library feature, and even then
it isn't really fully general: only the player has the benefit of a "player's
holdall" (hence the name), with other actors oblivious.

@<Define the Rucksack Class constant@> =
	if (K_players_holdall) {
		inter_name *iname = Hierarchy::find(RUCKSACK_CLASS_HL);
		Hierarchy::make_available(Emit::tree(), iname);
		Emit::named_iname_constant(iname, K_value, Kinds::RunTime::I6_classname(K_players_holdall));
	}

@ The following verifies, in a brute-force way, that there are no cycles in
the directed graph formed by the objects and progeniture. (We're doing this
now, rather than at Stage II above, because other plugins may also have
changed progenitors at Stage II.)

@<Check the well-foundedness of the hierarchy of the set of progenitors@> =
	instance *I;
	int max_loop = NUMBER_CREATED(instance) + 1;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		int k;
		instance *I2;
		for (I2 = PL::Spatial::progenitor(I), k=0; (I2) && (k<max_loop);
			I2 = PL::Spatial::progenitor(I2), k++) {
			if (I2 == I) {
				@<Diagnose the ill-foundedness with a problem message@>;
				PL::Spatial::void_progenitor(I); /* thus cutting the cycle */
				well_founded = FALSE;
			}
		}
	}

@ The cutest of all the object problem messages, really:

@<Diagnose the ill-foundedness with a problem message@> =
	Problems::quote_object(1, I);
	StandardProblems::handmade_problem(Task::syntax_tree(), _p_(PM_IllFounded));
	Problems::issue_problem_segment("The %1 seems to be containing itself: ");
	instance *I3 = I;
	while (TRUE) {
		wording IW = Instances::get_name(I3, FALSE);
		parse_node *creator = Diagrams::new_UNPARSED_NOUN(IW);
		Problems::quote_object(2, I3);
		Problems::quote_source(3, creator);
		Problems::issue_problem_segment("%2 (created by %3) ");
		if (PF_I(spatial, I3)->part_flag) Problems::issue_problem_segment("part of ");
		else Problems::issue_problem_segment("in ");
		I3 = PL::Spatial::progenitor(I3);
		if (I3 == I) break;
	}
	Problems::issue_problem_segment("%1... and so on. This is forbidden.");
	Problems::issue_problem_end();

@ Intermediate states are always suspect in program design, and we might
ask what's wrong with simply making the trees as we go along, rather than
storing all of those progenitors and then converting them into the trees.
We don't do that because (for reasons to do with "here" and with how work
is shared among the plugins) the progenitors are determined in an undefined
order; if we made the object tree as we went along, the spatial model would
be perfectly correct, but siblings -- say, the three things on the grass in
the Croquet Lawn -- would be compiled in the I6 code in some undefined
order. This order matters because it affects the text produced by typical
room descriptions: "You can also see a box, a ball and a peg here." might
become "You can also see a ball, a box and a peg here."

Inform therefore needs a definite rule of ordering, and this rule is that
siblings appear in their order of creation in the I7 source text, with the
first created being the eldest child. Looping over the objects to add them
to the trees in creation order achieves this nicely:

@<Expand the progenitor data into the two object trees@> =
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		if (PL::Spatial::progenitor(I))
			PL::Spatial::adopt_object(I, PL::Spatial::progenitor(I));
		if (PF_I(spatial, I)->part_flag)
			PL::Spatial::part_object(I);
	}

@ As a brief aside: if something is carried by a living person, we can
reasonably assume it's portable. (This is needed in particular to ensure that
supporters which are initially carried don't pick up "fixed in place" in
the absence of other information.)

@<Assert the portability of any item carried or supported by a person@> =
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		int portable = FALSE;
		instance *J = I;
		if (PF_I(spatial, I)->part_flag == FALSE)
			for (J = PL::Spatial::progenitor(I); J; J = PL::Spatial::progenitor(J)) {
				if (PF_I(spatial, J)->part_flag) break;
				if (Instances::of_kind(J, K_person)) {
					portable = TRUE;
					break;
				}
			}
		if (portable)
			Properties::EitherOr::assert(
				P_fixed_in_place, Instances::as_subject(I), FALSE, CERTAIN_CE);
	}

@<Assert I6-level properties to express the spatial structure@> =
	@<Assert an explicit default description value for the room kind@>;
	@<Assert room and thing indicator properties@>;
	@<Assert container and supporter indicator properties@>;
	@<Assert incorporation tree properties@>;

@ We need to make sure that every room does have an I6 |description| value
which can be written to (i.e., we need to avoid accidental use of the Z-machine's
readable-only default properties feature); hence the following, which ensures
that any room with no explicit description will inherit |EMPTY_TEXT_VALUE|
as a value for |description| from the room class.

@<Assert an explicit default description value for the room kind@> =
	if (K_room) {
		inference *inf;
		int desc_seen = FALSE;
		POSITIVE_KNOWLEDGE_LOOP(inf, Kinds::Knowledge::as_subject(K_room), PROPERTY_INF)
			if (World::Inferences::get_property(inf) == P_description)
				desc_seen = TRUE;
		if (desc_seen == FALSE) {
			TEMPORARY_TEXT(val)
			WRITE_TO(val, "\"\"");
			Properties::Valued::assert(P_description, Kinds::Knowledge::as_subject(K_room),
				Rvalues::from_unescaped_wording(Feeds::feed_text(val)), LIKELY_CE);
			DISCARD_TEXT(val)
		}
	}

@ These I6-only properties exist for speed. They're implemented in I6 as
attributes, which means that testing them is very fast and there is no memory
overhead for their storage. That shaves a little time off route-finding in
extensive maps.

@<Assert room and thing indicator properties@> =
	P_mark_as_room = Properties::EitherOr::new_nameless(L"mark_as_room");
	Properties::EitherOr::implement_as_attribute(P_mark_as_room, TRUE);
	P_mark_as_thing = Properties::EitherOr::new_nameless(L"mark_as_thing");
	Properties::EitherOr::implement_as_attribute(P_mark_as_thing, TRUE);
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		if (Instances::of_kind(I, K_room))
			Properties::EitherOr::assert(
				P_mark_as_room, Instances::as_subject(I), TRUE, CERTAIN_CE);
		if (Instances::of_kind(I, K_thing))
			Properties::EitherOr::assert(
				P_mark_as_thing, Instances::as_subject(I), TRUE, CERTAIN_CE);
	}

@<Assert container and supporter indicator properties@> =
	P_container = Properties::EitherOr::new_nameless(L"container");
	Properties::EitherOr::implement_as_attribute(P_container, TRUE);
	P_supporter = Properties::EitherOr::new_nameless(L"supporter");
	Properties::EitherOr::implement_as_attribute(P_supporter, TRUE);
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		if (Instances::of_kind(I, K_container))
			Properties::EitherOr::assert(
				P_container, Instances::as_subject(I), TRUE, CERTAIN_CE);
		if (Instances::of_kind(I, K_supporter))
			Properties::EitherOr::assert(
				P_supporter, Instances::as_subject(I), TRUE, CERTAIN_CE);
	}

@ The main spatial tree is expressed in the compiled I6 code in an implicit
way, using the I6 object tree, but the incorporation tree is expressed using
a triplet of I6-only properties:

@<Assert incorporation tree properties@> =
	P_component_parent =
		Properties::Valued::new_nameless(I"component_parent", K_object);
	P_component_child =
		Properties::Valued::new_nameless(I"component_child", K_object);
	P_component_sibling =
		Properties::Valued::new_nameless(I"component_sibling", K_object);

	if (K_thing) {
		parse_node *nothing_constant = Rvalues::new_nothing_object_constant();
		Properties::Valued::assert(P_component_parent, Kinds::Knowledge::as_subject(K_thing),
			nothing_constant, CERTAIN_CE);
		Properties::Valued::assert(P_component_child, Kinds::Knowledge::as_subject(K_thing),
			nothing_constant, CERTAIN_CE);
		Properties::Valued::assert(P_component_sibling, Kinds::Knowledge::as_subject(K_thing),
			nothing_constant, CERTAIN_CE);
	}

	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I) {
		instance *cp = PF_I(spatial, I)->incorp_tree_parent;
		if (cp) Properties::Valued::assert(P_component_parent, Instances::as_subject(I),
			Rvalues::from_instance(cp), CERTAIN_CE);
		instance *cc = PF_I(spatial, I)->incorp_tree_child;
		if (cc) Properties::Valued::assert(P_component_child, Instances::as_subject(I),
			Rvalues::from_instance(cc), CERTAIN_CE);
		instance *cs = PF_I(spatial, I)->incorp_tree_sibling;
		if (cs) Properties::Valued::assert(P_component_sibling, Instances::as_subject(I),
			Rvalues::from_instance(cs), CERTAIN_CE);
	}

@ Because Inform 6 requires objects to be defined in a traversal order for
the main spatial tree (only the main one because I6 has no concept of
incorporation), we use the main tree to determine the compilation sequence
for objects:

@<Set up the compilation sequence so that it traverses the main object tree@> =
	Instances::begin_sequencing_objects();
	instance *I;
	LOOP_OVER_OBJECT_INSTANCES(I)
		if (PF_I(spatial, I)->object_tree_parent == NULL)
			PL::Spatial::add_to_object_sequence(I, 0);

@ =
void PL::Spatial::add_to_object_sequence(instance *I, int depth) {
	Instances::place_this_object_next(I);
	PF_I(spatial, I)->I6_definition_depth = depth;

	if (PF_I(spatial, I)->object_tree_child)
		PL::Spatial::add_to_object_sequence(PF_I(spatial, I)->object_tree_child, depth+1);
	if (PF_I(spatial, I)->object_tree_sibling)
		PL::Spatial::add_to_object_sequence(PF_I(spatial, I)->object_tree_sibling, depth);
}

@ The "definition depth" is the same thing as the depth in the main tree;
0 for a room, 1 for a player standing in that room, 2 for his hat, and so on.

=
int PL::Spatial::get_definition_depth(instance *I) {
	if (Plugins::Manage::plugged_in(spatial_plugin))
		return PF_I(spatial, I)->I6_definition_depth;
	return 0;
}

@ At last, Stage IV. We're all done except for a little checking of the
degenerate case where Inform is just binding up an existing story file, so
that there's really no spatial model at all -- the world is, or should be,
empty.

=
int PL::Spatial::spatial_stage_IV(void) {
	if (Task::wraps_existing_storyfile()) {
		instance *I;
		LOOP_OVER_OBJECT_INSTANCES(I)
			if (PL::Spatial::object_is_a_room(I)) {
				StandardProblems::unlocated_problem(Task::syntax_tree(), _p_(PM_RoomInIgnoredSource),
					"This is supposed to be a source text which only contains "
					"release instructions to bind up an existing story file "
					"(for instance, one produced using Inform 6). That's because "
					"the instruction 'Release along with an existing story file' "
					"is present. So the source text must not contain rooms or "
					"other game design - these would be ignored.");
				break;
			}
	}
	return FALSE;
}

@ =
void PL::Spatial::index_spatial_relationship(OUTPUT_STREAM, instance *I) {
	char *rel = NULL;
	instance *P = PL::Spatial::progenitor(I);
	if (P) {
		/* we could set |rel| to "in" here, but the index omits that for clarity */
		if (Instances::of_kind(P, K_supporter)) rel = "on";
		if (Instances::of_kind(P, K_person)) rel = "carried";
		if (PF_I(spatial, I)->part_flag) rel = "part";
		inference *inf;
		POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(I), PROPERTY_INF)
			if (World::Inferences::get_property(inf) == P_worn)
				rel = "worn";
	}
	if (rel) WRITE("<i>%s</i> ", rel);
}

@ If something is a part, we don't detail it on the World index page, since
it already turns up under its owner.

=
int PL::Spatial::no_detail_index(instance *I) {
	if (PF_I(spatial, I)->incorp_tree_parent != NULL) return TRUE;
	return FALSE;
}

@ In the World index, we recurse to show the contents and parts:

=
void PL::Spatial::index_object_further(OUTPUT_STREAM, instance *I, int depth, int details) {
	if (depth > NUMBER_CREATED(instance) + 1) return; /* to recover from errors */
	if (PF_I(spatial, I)->incorp_tree_child != NULL) {
		instance *I2 = PF_I(spatial, I)->incorp_tree_child;
		while (I2 != NULL) {
			Data::Objects::index(OUT, I2, NULL, depth+1, details);
			I2 = PF_I(spatial, I2)->incorp_tree_sibling;
		}
	}
	if (PF_I(spatial, I)->object_tree_child)
		Data::Objects::index(OUT, PF_I(spatial, I)->object_tree_child, NULL, depth+1, details);
	if ((PL::Spatial::object_is_a_room(I)) &&
		(PL::Map::object_is_a_door(I) == FALSE)) {
		instance *I2;
		LOOP_OVER_OBJECT_INSTANCES(I2) {
			if ((PL::Map::object_is_a_door(I2)) && (PL::Spatial::progenitor(I2) != I)) {
				instance *A = NULL, *B = NULL;
				PL::Map::get_door_data(I2, &A, &B);
				if (A == I) Data::Objects::index(OUT, I2, NULL, depth+1, details);
				if (B == I) Data::Objects::index(OUT, I2, NULL, depth+1, details);
			}
		}
	}
	PL::Player::index_object_further(OUT, I, depth, details);
	PL::Backdrops::index_object_further(OUT, I, depth, details, 0);

	if (PF_I(spatial, I)->object_tree_sibling)
		Data::Objects::index(OUT, PF_I(spatial, I)->object_tree_sibling, NULL, depth, details);
}

@ And also:

=
int PL::Spatial::spatial_add_to_World_index(OUTPUT_STREAM, instance *O) {
	if ((O) && (Instances::of_kind(O, K_thing))) {
		HTML::open_indented_p(OUT, 1, "tight");
		instance *P = PL::Spatial::progenitor(O);
		if (P) {
			WRITE("<i>initial location:</i> ");
			char *rel = "in";
			if (Instances::of_kind(P, K_supporter)) rel = "on";
			if (Instances::of_kind(P, K_person)) rel = "carried by";
			if (PF_I(spatial, O)->part_flag) rel = "part of";
			inference *inf;
			POSITIVE_KNOWLEDGE_LOOP(inf, Instances::as_subject(O), PROPERTY_INF)
				if (World::Inferences::get_property(inf) == P_worn)
					rel = "worn by";
			WRITE("%s ", rel);
			Instances::index_name(OUT, P);
			parse_node *at = PF_I(spatial, O)->progenitor_set_at;
			if (at) Index::link(OUT, Wordings::first_wn(Node::get_text(at)));

		}
		HTML_CLOSE("p");
	}
	return FALSE;
}
