[VerbUsages::] Verb Usages.

To parse the many forms a verb can take.

@h Definitions.

@ The "permitted verb" is just a piece of temporary context used in parsing:
it's convenient for the verb currently being considered to be stored in
a global variable.

=
verb_identity *permitted_verb_identity = NULL;

@h Verb usages.
We already have the ability to conjugate verbs -- to turn "to have" into "I have",
"you have", "he has", "they have had", "we will have" and so on -- from the
Inflections module. However, we won't necessarily want to recognise all of
those forms in sentences in the source text. For example, Inform only looks
at present tense forms of verbs in the third person, or at imperative forms.

To be recognised as referring to a given verb, a conjugated form of it must
be turned into one of the following structures:

=
typedef struct verb_usage {
	struct word_assemblage vu_text;			/* text to recognise */
	int vu_allow_unexpected_upper_case; 	/* for verbs like "to Hoover" or "to Google" */

	struct verb_identity *verb_used;
	int negated_form_of_verb; 				/* is this a negated form? */
	int mood;								/* active/passive: one of the two |*_MOOD| values */
	int tensed; 							/* one of the |*_TENSE| values */

	#ifdef CORE_MODULE
	struct lexicon_entry *vu_lex_entry; 	/* for use when indexing */
	#endif
	struct parse_node *where_vu_created; 	/* for use if problem messages needed */

	struct verb_usage *next_in_search_list; /* within a linked list of all usages in length order */
	struct verb_usage *next_within_tier;	/* within the linked list for this tier (see below) */
	MEMORY_MANAGEMENT
} verb_usage;

verb_usage *regular_to_be = NULL; /* "is" */
verb_usage *negated_to_be = NULL; /* "is not" */

@ One simple search list arranges these in order of (word count) length:

=
verb_usage *vu_search_list = NULL; /* head of linked list of usages in length order */

@d LOOP_OVER_USAGES(vu)
	for (vu = vu_search_list; vu; vu = vu->next_in_search_list)

@h Verb usage tiers.
A particular challenge of parsing natural language is to decide the most likely
word in a sentence to be its primary verb. (The verb in "Heatwave Bone Breaks
Clog Hospital" is not "to break".) This is especially challenging when the
noun phrases can't be understood since they refer to things not yet created.
In Inform, for example, "Peter wears a felt hat" might be the only reference
anywhere in the source text to either Peter or the hat, which must each be
created in response to this sentence, and therefore can't be used to
understand it.

The model we use is to sort verb usages into "tiers", each with a numerical
"priority", which is a non-negative number. Tier 0 verb usages are never
recognised. Otherwise, the lower the priority number, the more likely it
is that this verb is meant. If two usages belong to the same tier, then
the earlier one in the sentence is preferred.

The tiers are stored as a linked list, in priority order:

=
typedef struct verb_usage_tier {
	int priority;
	struct verb_usage *tier_contents; /* head of linked list for this tier */
	struct verb_usage_tier *next_tier;
	MEMORY_MANAGEMENT
} verb_usage_tier;

verb_usage_tier *first_search_tier = NULL; /* head of linked list of tiers */

@h Registration.
Here we create a single verb usage; note that the empty text cannot be used.

=
parse_node *set_where_created = NULL;
verb_usage *VerbUsages::register_single_usage(word_assemblage wa, int negated, int tense,
	int mood, verb_identity *vi, int unexpected_upper_casing_used) {
	if (WordAssemblages::nonempty(wa) == FALSE) return NULL;
	LOGIF(VERB_USAGES, "new usage: '%A'\n", &wa);
	VerbUsages::mark_as_verb(WordAssemblages::first_word(&wa));
	verb_usage *vu = CREATE(verb_usage);
	vu->vu_text = wa;
	vu->negated_form_of_verb = negated; vu->tensed = tense;
	#ifdef CORE_MODULE
	vu->vu_lex_entry = current_main_verb;
	#endif
	vu->where_vu_created = set_where_created;
	vu->verb_used = vi;
	vu->mood = mood;
	vu->vu_allow_unexpected_upper_case = unexpected_upper_casing_used;
	vu->next_within_tier = NULL;
	vu->next_in_search_list = NULL;
	@<Add to the length-order search list@>;
	return vu;
}

@ These are insertion-sorted into a list in order of word count, with oldest
first in the case of equal length:

@<Add to the length-order search list@> =
	if (vu_search_list == NULL) vu_search_list = vu;
	else {
		for (verb_usage *evu = vu_search_list, *prev = NULL; evu; prev = evu, evu = evu->next_in_search_list) {
			if (WordAssemblages::longer(&wa, &(evu->vu_text)) > 0) {
				vu->next_in_search_list = evu;
				if (prev == NULL) vu_search_list = vu;
				else prev->next_in_search_list = vu;
				break;
			}
			if (evu->next_in_search_list == NULL) {
				evu->next_in_search_list = vu;
				break;
			}
		}
	}

@h Registration of regular verbs.
It would be tiresome to have to call the above routine for every possible
conjugated form of a verb individually, so the following takes care of
a whole verb at once.

The copular verb has no passive, since it doesn't distinguish between
subject and object. In English, we can say "the hat is worn by Peter"
as equivalent to "Peter wears the hat", but not "1 is been by X" as
equivalent to "X is 1".

=
void VerbUsages::register_all_usages_of_verb(verb_identity *vi,
	int unexpected_upper_casing_used, int priority) {
	verb_conjugation *vc = vi->conjugation;
	if (vc == NULL) return;
	#ifdef CORE_MODULE
	Index::Lexicon::new_main_verb(vc->infinitive, VERB_LEXE);
	#endif

	VerbUsages::register_moods_of_verb(vc, ACTIVE_MOOD, vi,
		unexpected_upper_casing_used, priority);

	if (vi != copular_verb) {
		VerbUsages::register_moods_of_verb(vc, PASSIVE_MOOD, vi,
			unexpected_upper_casing_used, priority);
		@<Add present participle forms@>;
	}
}

@ With the present participle the meaning is back the right way around: for
instance, "to be fetching" has the same meaning as "to fetch". At any rate,
Inform's linguistic model is not subtle enough to distinguish the difference,
in terms of a continuous rather than instantaneous process, which a human
reader might be aware of.

Partly because of that, we don't allow these forms for the copular verb:
"He is being difficult" doesn't quite mean "He is difficult", which is the
best sense we could make of it, and "He is being in the Dining Room" has
an unfortunate mock-Indian sound to it.

@<Add present participle forms@> =
	if (WordAssemblages::nonempty(vc->present_participle)) {
		preposition_identity *prep =
			Prepositions::make(vc->present_participle, unexpected_upper_casing_used);
		Verbs::add_form(copular_verb, prep, NULL,
			VerbMeanings::new_indirection(vi, FALSE), SVO_FS_BIT);
	}

@ Note that forms using the auxiliary "to be" are given meanings which indirect
to the meanings of the main verb: thus "Y is owned by X" is indirected to
the reversal of the meaning "X owns Y", and "X is owning Y" to the unreversed
meaning. Both forms are then internally implemented as prepositional forms
of "to be", which is convenient however dubious in linguistic terms.

=
void VerbUsages::register_moods_of_verb(verb_conjugation *vc, int mood,
	verb_identity *vi, int unexpected_upper_casing_used, int priority) {
	verb_tabulation *vt = &(vc->tabulations[mood]);
	if (WordAssemblages::nonempty(vt->to_be_auxiliary)) {
		preposition_identity *prep =
			Prepositions::make(vt->to_be_auxiliary, unexpected_upper_casing_used);
		Verbs::add_form(copular_verb, prep, NULL,
			VerbMeanings::new_indirection(vi, (mood == PASSIVE_MOOD)?TRUE:FALSE),
			SVO_FS_BIT);
		return;
	}
	@<Register usages@>;
}

@ The sequence of registration is important here, and it's done this way to
minimise false readings due to overlaps. We take future or other exotic
tenses (say, the French past historic) first; then the perfect tenses,
then the imperfect; within that, we take negated forms first, then positive;
within that, we take present before past tense; within that, we run through
the persons from 1PS to 3PP.

@<Register usages@> =
	for (int tense = WILLBE_TENSE; tense < NO_KNOWN_TENSES; tense++)
		for (int sense = 1; sense >= 0; sense--)
			@<Register usages in this combination@>;

	int t1 = HASBEEN_TENSE, t2 = HADBEEN_TENSE;
	@<Register usages in these tenses@>;
	t1 = IS_TENSE; t2 = WAS_TENSE;
	@<Register usages in these tenses@>;

@<Register usages in these tenses@> =
	for (int sense = 1; sense >= 0; sense--) {
		int tense = t1;
		@<Register usages in this combination@>;
		tense = t2;
		@<Register usages in this combination@>;
	}

@ Note that before a usage is registered, we call out to the client to find
out whether it's needed.

@<Register usages in this combination@> =
	for (int person = 0; person < NO_KNOWN_PERSONS; person++) {
		int p = priority;
		#ifdef ALLOW_VERB_USAGE_IN_ASSERTIONS
		if (ALLOW_VERB_USAGE_IN_ASSERTIONS(vc, tense, sense, person) == FALSE) p = 0;
		#else
		if (VerbUsages::allow_in_assertions(vc, tense, sense, person) == FALSE) p = 0;
		#endif
		#ifdef ALLOW_VERB_USAGE_GENERALLY
		if (ALLOW_VERB_USAGE_GENERALLY(vc, tense, sense, person) == FALSE) p = -1;
		#else
		if (VerbUsages::allow_generally(vc, tense, sense, person) == FALSE) p = -1;
		#endif
		if (p >= 0) @<Actually register this usage@>;
	}

@<Actually register this usage@> =
	verb_usage *vu = VerbUsages::register_single_usage(vt->vc_text[tense][sense][person],
		(sense==1)?TRUE:FALSE, tense, mood, vi, unexpected_upper_casing_used);
	if (vu) VerbUsages::set_search_priority(vu, p);
	if (vi == copular_verb) {
		if ((tense == IS_TENSE) && (person == THIRD_PERSON_SINGULAR)) {
			if (sense == 1) negated_to_be = vu;
			else regular_to_be = vu;
		}
	}

@ Here are the default decisions on what usages are allowed; the defaults are
what are used by Inform. In assertions:

=
int VerbUsages::allow_in_assertions(verb_conjugation *vc, int tense, int sense, int person) {
	if ((tense == IS_TENSE) &&
		(sense == 0) &&
		((person == THIRD_PERSON_SINGULAR) || (person == THIRD_PERSON_PLURAL)))
		return TRUE;
	return FALSE;
}

@ And in other usages (e.g., in Inform's "now the pink door is not open"):

=
int VerbUsages::allow_generally(verb_conjugation *vc, int tense, int sense, int person) {
	if (((tense == IS_TENSE) || (tense == WAS_TENSE) ||
		(tense == HASBEEN_TENSE) || (tense == HADBEEN_TENSE)) &&
		((person == THIRD_PERSON_SINGULAR) || (person == THIRD_PERSON_PLURAL)))
		return TRUE;
	return FALSE;
}

@ That just leaves the business of setting the "priority" of a usage. As
noted above, priority 0 usages are ignored, while otherwise low numbers
beat high ones. For example, in "The verb to be means the equality relation",
the verb "be" might have priority 2 and so be beaten by the verb "mean",
with priority 1.

We must add the new usage to the tier with the given priority, creating
that tier if need be. Newly created tiers are insertion-sorted into a
list, with lower priority numbers before higher ones.

=
void VerbUsages::set_search_priority(verb_usage *vu, int p) {
	verb_usage_tier *tier = first_search_tier, *last_tier = NULL;
	LOGIF(VERB_USAGES, "Usage '%A' has priority %d\n", &(vu->vu_text), p);
	while ((tier) && (tier->priority <= p)) {
		if (tier->priority == p) {
			VerbUsages::add_to_tier(vu, tier);
			return;
		}
		last_tier = tier;
		tier = tier->next_tier;
	}
	tier = CREATE(verb_usage_tier);
	tier->priority = p;
	tier->tier_contents = NULL;
	VerbUsages::add_to_tier(vu, tier);
	if (last_tier) {
		tier->next_tier = last_tier->next_tier;
		last_tier->next_tier = tier;
	} else {
		tier->next_tier = first_search_tier;
		first_search_tier = tier;
	}
}

void VerbUsages::add_to_tier(verb_usage *vu, verb_usage_tier *tier) {
	verb_usage *known = tier->tier_contents;
	while ((known) && (known->next_within_tier))
		known = known->next_within_tier;
	if (known) known->next_within_tier = vu;
	else tier->tier_contents = vu;
	vu->next_within_tier = NULL;
}

@h Miscellaneous utility routines.
A usage is "foreign" if it belongs to a language other than English:

=
int VerbUsages::is_foreign(verb_usage *vu) {
	if ((vu->verb_used) &&
		(vu->verb_used->conjugation->defined_in) &&
		(vu->verb_used->conjugation->defined_in != English_language)) {
		return TRUE;
	}
	return FALSE;
}

@ And some access routines.

=
VERB_MEANING_TYPE *VerbUsages::get_regular_meaning(verb_usage *vu, preposition_identity *prep, preposition_identity *second_prep) {
	if (vu == NULL) return NULL;
	verb_meaning *uvm = Verbs::regular_meaning(vu->verb_used, prep, second_prep);

	if (uvm == NULL) return NULL;
	VERB_MEANING_TYPE *root = VerbMeanings::get_relational_meaning(uvm);
	if ((vu->mood == PASSIVE_MOOD) && (root != VERB_MEANING_EQUALITY))
		root = VERB_MEANING_REVERSAL(root);
	return root;
}

int VerbUsages::get_tense_used(verb_usage *vu) {
	return vu->tensed;
}

int VerbUsages::is_used_negatively(verb_usage *vu) {
	return vu->negated_form_of_verb;
}

@h Parsing source text against verb usages.
Given a particular VU, and a word range |w1| to |w2|, we test whether the
range begins with but does not consist only of the text of the VU. We return
the first word after the VU text if it does (which will therefore be a
word number still inside the range), or $-1$ if it doesn't.

It is potentially quite slow to test every word against every possible verb,
even though there are typically fairly few verbs in the S-grammar, so we
confine ourselves to words flagged in the vocabulary as being used in verbs.

=
int VerbUsages::parse_against_verb(wording W, verb_usage *vu) {
	if ((vu->vu_allow_unexpected_upper_case == FALSE) &&
		(Word::unexpectedly_upper_case(Wordings::first_wn(W)))) return -1;
	return WordAssemblages::parse_as_strictly_initial_text(W, &(vu->vu_text));
}

@ We now define a whole run of internals to parse verbs. As examples,

>> is
>> has not been
>> was carried by

are all, in the sense we mean it here, "verbs".

We never match a verb if it is unexpectedly given in upper case form. Thus
"The Glory That Is Rome is a room" will be read as "(The Glory That Is
Rome) is (a room)", not "(The Glory That) is (Rome is a room)".

The following picks up any verb which can be used in an SVO sentence and
which has a meaning.

=
<meaningful-nonimperative-verb> internal ? {
	verb_usage *vu;
	LOOP_OVER_USAGES(vu) {
		verb_identity *vi = vu->verb_used;
		for (verb_form *vf = vi->list_of_forms; vf; vf = vf->next_form)
			if ((VerbMeanings::is_meaningless(&(vf->list_of_senses->vm)) == FALSE) &&
				(vf->form_structures & (SVO_FS_BIT + SVOO_FS_BIT))) {
				int i = VerbUsages::parse_against_verb(W, vu);
				if ((i>Wordings::first_wn(W)) && (i<=Wordings::last_wn(W))) {
					if ((vf->preposition == NULL) ||
						(WordAssemblages::is_at(&(vf->preposition->prep_text), i, Wordings::last_wn(W)))) {
						*XP = vu;
						permitted_verb_identity = vu->verb_used;
						return i-1;
					}
				}
			}
	}
	return FALSE;
}

@ A copular verb is one which implies the equality relation: in practice,
that means it's "to be". So the following matches "is", "were not",
and so on.

=
<copular-verb> internal ? {
	verb_usage *vu;
	if (preform_backtrack) { vu = preform_backtrack; goto BacktrackFrom; }
	LOOP_OVER_USAGES(vu) {
		if (vu->verb_used == copular_verb) {
			int i = VerbUsages::parse_against_verb(W, vu);
			if ((i>Wordings::first_wn(W)) && (i<=Wordings::last_wn(W))) {
				*XP = vu;
				return -(i-1);
			}
			BacktrackFrom: ;
		}
	}
	return FALSE;
}

@ A noncopular verb is anything that isn't copular, but here we also require
it to be in the present tense and the negative sense. So, for example, "does
not carry" qualifies; "is not" or "supports" don't qualify.

=
<negated-noncopular-verb-present> internal ? {
	verb_usage *vu;
	if (preform_backtrack) { vu = preform_backtrack; goto BacktrackFrom; }
	LOOP_OVER_USAGES(vu) {
		if ((vu->tensed == IS_TENSE) &&
			(vu->verb_used != copular_verb) &&
			(vu->negated_form_of_verb == TRUE)) {
			int i = VerbUsages::parse_against_verb(W, vu);
			if ((i>Wordings::first_wn(W)) && (i<=Wordings::last_wn(W))) {
				*XP = vu;
				return -(i-1);
			}
			BacktrackFrom: ;
		}
	}
	return FALSE;
}

@ A universal verb is one which implies the universal relation: in practice,
that means it's "to relate".

=
<universal-verb> internal ? {
	#ifdef VERB_MEANING_UNIVERSAL
	verb_usage *vu;
	LOOP_OVER_USAGES(vu)
		if (VerbUsages::get_regular_meaning(vu, NULL, NULL) == VERB_MEANING_UNIVERSAL) {
			int i = VerbUsages::parse_against_verb(W, vu);
			if ((i>Wordings::first_wn(W)) && (i<=Wordings::last_wn(W))) {
				*XP = vu;
				return i-1;
			}
		}
	#endif
	return FALSE;
}

@
Any verb usage which is negative in sense: this is used only to diagnose problems.

=
<negated-verb> internal ? {
	verb_usage *vu;
	if (preform_backtrack) { vu = preform_backtrack; goto BacktrackFrom; }
	LOOP_OVER_USAGES(vu) {
		if (vu->negated_form_of_verb == TRUE) {
			int i = VerbUsages::parse_against_verb(W, vu);
			if ((i>Wordings::first_wn(W)) && (i<=Wordings::last_wn(W))) {
				*XP = vu;
				return -(i-1);
			}
			BacktrackFrom: ;
		}
	}
	return FALSE;
}

@ Any verb usage which is in the past tense: this is used only to diagnose problems.

=
<past-tense-verb> internal ? {
	verb_usage *vu;
	if (preform_backtrack) { vu = preform_backtrack; goto BacktrackFrom; }
	LOOP_OVER_USAGES(vu) {
		if (vu->tensed != IS_TENSE) {
			int i = VerbUsages::parse_against_verb(W, vu);
			if ((i>Wordings::first_wn(W)) && (i<=Wordings::last_wn(W))) {
				*XP = vu;
				return -(i-1);
			}
			BacktrackFrom: ;
		}
	}
	return FALSE;
}

@ The following are used only when recognising text expansions for adaptive
uses of verbs:

=
<adaptive-verb> internal {
	verb_conjugation *vc;
	LOOP_OVER(vc, verb_conjugation)
		if (vc->auxiliary_only == FALSE) {
			int p = PREFORM_ADAPTIVE_PERSON(vc->defined_in);
			word_assemblage *we_form = &(vc->tabulations[ACTIVE_MOOD].vc_text[IS_TENSE][0][p]);
			word_assemblage *we_dont_form = &(vc->tabulations[ACTIVE_MOOD].vc_text[IS_TENSE][1][p]);
			if (WordAssemblages::compare_with_wording(we_form, W)) {
				*XP = vc; *X = FALSE; return TRUE;
			}
			if (WordAssemblages::compare_with_wording(we_dont_form, W)) {
				*XP = vc; *X = TRUE; return TRUE;
			}
		}
	return FALSE;
}

<adaptive-verb-infinitive> internal {
	verb_conjugation *vc;
	LOOP_OVER(vc, verb_conjugation)
		if (vc->auxiliary_only == FALSE) {
			word_assemblage *infinitive_form = &(vc->infinitive);
			if (WordAssemblages::compare_with_wording(infinitive_form, W)) {
				*XP = vc; *X = FALSE; return TRUE;
			}
		}
	return FALSE;
}

@ These three nonterminals are used by Inform only to recognise constant
names for verbs. For example, the parsing of the Inform constants "the verb take"
or "the verb to be able to see" use these.

=
<instance-of-verb> internal {
	verb_form *vf;
	LOOP_OVER(vf, verb_form) {
		verb_conjugation *vc = vf->underlying_verb->conjugation;
		if ((vc->auxiliary_only == FALSE) && (vc->instance_of_verb)) {
			if (WordAssemblages::compare_with_wording(&(vf->pos_reference_text), W)) {
				*XP = vf; *X = FALSE; return TRUE;
			}
			if (WordAssemblages::compare_with_wording(&(vf->neg_reference_text), W)) {
				*XP = vf; *X = TRUE; return TRUE;
			}
		}
	}
	return FALSE;
}

<instance-of-infinitive-form> internal {
	verb_form *vf;
	LOOP_OVER(vf, verb_form) {
		verb_conjugation *vc = vf->underlying_verb->conjugation;
		if ((vc->auxiliary_only == FALSE) && (vc->instance_of_verb)) {
			if (WordAssemblages::compare_with_wording(&(vf->infinitive_reference_text), W)) {
				*XP = vf; *X = FALSE; return TRUE;
			}
		}
	}
	return FALSE;
}

<modal-verb> internal {
	verb_conjugation *vc;
	LOOP_OVER(vc, verb_conjugation)
		if (vc->auxiliary_only == FALSE) {
			int p = PREFORM_ADAPTIVE_PERSON(vc->defined_in);
			if (vc->tabulations[ACTIVE_MOOD].modal_auxiliary_usage[IS_TENSE][0][p] != 0) {
				word_assemblage *we_form = &(vc->tabulations[ACTIVE_MOOD].vc_text[IS_TENSE][0][p]);
				word_assemblage *we_dont_form = &(vc->tabulations[ACTIVE_MOOD].vc_text[IS_TENSE][1][p]);
				if (WordAssemblages::compare_with_wording(we_form, W)) {
					*XP = vc; *X = FALSE; return TRUE;
				}
				if (WordAssemblages::compare_with_wording(we_dont_form, W)) {
					*XP = vc; *X = TRUE; return TRUE;
				}
			}
		}
	return FALSE;
}

@h Optimisation.

=
void VerbUsages::mark_as_verb(vocabulary_entry *ve) {
	Preform::set_nt_incidence(ve, <meaningful-nonimperative-verb>);
	Preform::set_nt_incidence(ve, <copular-verb>);
	Preform::set_nt_incidence(ve, <negated-noncopular-verb-present>);
	Preform::set_nt_incidence(ve, <universal-verb>);
	Preform::set_nt_incidence(ve, <negated-verb>);
	Preform::set_nt_incidence(ve, <past-tense-verb>);
}

void VerbUsages::preform_optimiser(void) {
	Preform::mark_nt_as_requiring_itself_first(<meaningful-nonimperative-verb>);
	Preform::mark_nt_as_requiring_itself_first(<copular-verb>);
	Preform::mark_nt_as_requiring_itself_first(<negated-noncopular-verb-present>);
	Preform::mark_nt_as_requiring_itself_first(<universal-verb>);
	Preform::mark_nt_as_requiring_itself_first(<negated-verb>);
	Preform::mark_nt_as_requiring_itself_first(<past-tense-verb>);
}
