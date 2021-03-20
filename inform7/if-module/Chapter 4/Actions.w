[Actions::] Actions.

Each different sort of impulse to do something is an "action name".

@ An action is an impulse to do something within the model world, and there
will be many different sorts of impulse which a person may have: "going"
[i.e. somewhere], for example, or "wearing" [i.e. something].

Each of these different sorts of action is represented by an instance of
//action_name//, and each in turn corresponds to an instance of the enumerated
kind |K_action_name| at run-time. 

=
typedef struct action_name {
	struct action_naming_data naming_data;

	struct action_semantics semantics; /* see //Action Semantics// */

	struct rulebook *check_rules; /* rulebooks private to this action */
	struct rulebook *carry_out_rules;
	struct rulebook *report_rules;
	struct stacked_variable_owner *action_variables;

	struct cg_line *command_parser_grammar_producing_this; /* if any */

	struct action_compilation_data compilation_data;
	struct action_indexing_data indexing_data;
	CLASS_DEFINITION
} action_name;

@ Note that we notify the |K_action_name| kind that a new enumerated value
for it exists; we don't need to record the reply (i.e. the number used as
this value at run-time) because it will be the same as the allocation ID
for the //action_name// structure in all cases.

As a historical note, until 2021 this code was still capable of generating
actions managed entirely by Inter code and without I7 rulebooks: something
which had not actually been done since around 2008.

=
action_name *Actions::act_new(wording W) {
	action_name *an = CREATE(action_name);
	Kinds::Behaviour::new_enumerated_value(K_action_name);

	ActionNameNames::baptise(an, W); /* which sets its |naming_data| */

	an->semantics = ActionSemantics::default();

	an->command_parser_grammar_producing_this = NULL;

	an->compilation_data = RTActions::new_data(W);
	an->indexing_data = IXActions::new_data();
	
	an->check_rules =      Actions::new_rulebook(an, CHECK_RB_HL);
	an->carry_out_rules =  Actions::new_rulebook(an, CARRY_OUT_RB_HL);
	an->report_rules =     Actions::new_rulebook(an, REPORT_RB_HL);
	an->action_variables =
		StackedVariables::new_owner(RTActions::action_variable_set_ID(an));

	LOGIF(ACTION_CREATIONS, "Created action: %W\n", W);
	return an;
}

@ Rulebooks such as "check" would become far too large if they accumulated
every rule for checking anything; and so they are "fragmented" into individual
rulebooks per action, such as "check waiting" or "check dropping".

=
rulebook *Actions::new_rulebook(action_name *an, int RB) {
	wording W = ActionNameNames::rulebook_name(an, RB);
	int prefix_length = Wordings::length(W) -
		Wordings::length(ActionNameNames::tensed(an, IS_TENSE));
	rulebook *R = Rulebooks::new_automatic(W, K_action_name, NO_OUTCOME,
		TRUE, FALSE, FALSE, RTActions::rulebook_package(an, RB));
	Rulebooks::fragment_by_actions(R, prefix_length);
	return R;
}

@ These functions goes from the global rulebook to the fragmented one for
a given action:

=
rulebook *Actions::fragment_rulebook(action_name *an, rulebook *rb) {
	if (rb == built_in_rulebooks[CHECK_RB])     return an->check_rules;
	if (rb == built_in_rulebooks[CARRY_OUT_RB]) return an->carry_out_rules;
	if (rb == built_in_rulebooks[REPORT_RB])    return an->report_rules;
	internal_error("asked for peculiar fragmented rulebook"); return NULL;
}

rulebook *Actions::divert_to_another_actions_rulebook(action_name *new_an,
	rulebook *old_rulebook) {
	if (new_an) {
		action_name *old_an;
		LOOP_OVER(old_an, action_name) {
			if (old_rulebook == old_an->check_rules)     return new_an->check_rules;
			if (old_rulebook == old_an->carry_out_rules) return new_an->carry_out_rules;
			if (old_rulebook == old_an->report_rules)    return new_an->report_rules;
		}
	}
	return old_rulebook;
}

@ And this is where the actions plugin moves rules from their normal rulebooks:

=
int Actions::divert_rule(rule *R, rulebook *original_owner, rulebook **new_owner) {
	phrase *ph = Rules::get_defn_as_phrase(R); if (ph == NULL) return FALSE;
	if (Rulebooks::requires_specific_action(original_owner)) {
		int waiver = FALSE;
		action_name *an = NULL;
		wording PW = Phrases::Usage::get_prewhile_text(&(ph->usage_data));
		if (Wordings::nonempty(PW)) {
			LOOP_THROUGH_WORDING(i, PW)
				if (NamedActionPatterns::by_name(Wordings::from(PW, i)))
					@<Issue PM_MultipleCCR@>;
			int anyone = FALSE;
			action_name_list *list = ParseActionPatterns::list_of_actions_only(PW, &anyone);
			LOGIF(RULE_ATTACHMENTS, "Looking at '%W' (anyone flag %d):\n$L\n",
				PW, anyone, list);
			an = ActionNameLists::get_best_action(list);
			LOGIF(RULE_ATTACHMENTS, "Best action is $l\n", an);
			Rules::set_marked_for_anyone(R, anyone);
		} else {
			waiver = TRUE;
			if (original_owner == built_in_rulebooks[CHECK_RB])     waiver = FALSE;
			if (original_owner == built_in_rulebooks[CARRY_OUT_RB]) waiver = FALSE;
			if (original_owner == built_in_rulebooks[REPORT_RB])    waiver = FALSE;
		}
		if ((an == NULL) && (waiver == FALSE))
			an = ActionNameNames::longest_nounless(PW, IS_TENSE, NULL);
		if ((an == NULL) && (waiver == FALSE)) @<Issue PM_MultipleCCR@>;
		if (original_owner == built_in_rulebooks[CHECK_RB]) {
			*new_owner = Actions::fragment_rulebook(an, built_in_rulebooks[CHECK_RB]);
			return TRUE;
		} else if (original_owner == built_in_rulebooks[CARRY_OUT_RB]) {
			*new_owner = Actions::fragment_rulebook(an, built_in_rulebooks[CARRY_OUT_RB]);
			return TRUE;
		} else if (original_owner == built_in_rulebooks[REPORT_RB]) {
			*new_owner = Actions::fragment_rulebook(an, built_in_rulebooks[REPORT_RB]);
			return TRUE;
		} else {
			*new_owner = Actions::divert_to_another_actions_rulebook(an, original_owner);
			return TRUE;
		}
	}
	return FALSE;
}

@<Issue PM_MultipleCCR@> =
	Problems::quote_source(1, current_sentence);
	Problems::quote_wording(2, PW);
	StandardProblems::handmade_problem(Task::syntax_tree(), _p_(PM_MultipleCCR));
	Problems::issue_problem_segment(
		"You wrote %1, but the situation this refers to ('%2') is not a single "
		"action. Rules in the form of 'check', 'carry out' and 'report' are "
		"tied to specific actions, and must give a single explicit action name - "
		"even if they then go on to very complicated conditions about any nouns "
		"also involved. So 'Check taking something: ...' is fine, but not 'Check "
		"taking or dropping something: ...' or 'Check doing something: ...' - "
		"the former names two actions, the latter none.");
	Problems::issue_problem_end();
	return FALSE;

@ The //Parsing Plugin// attaches command grammar to an action, but that's not
our concern here:

=
void Actions::add_gl(action_name *an, cg_line *cgl) {
	if (an->command_parser_grammar_producing_this == NULL)
		an->command_parser_grammar_producing_this = cgl;
	else
		CommandsIndex::list_with_action_add(
			an->command_parser_grammar_producing_this, cgl);
}

void Actions::remove_all_command_grammar(action_name *an) {
	an->command_parser_grammar_producing_this = NULL;
	command_grammar *cg;
	LOOP_OVER(cg, command_grammar) CommandGrammars::remove_action(cg, an);
}

@ Most actions are given automatically generated Inter identifiers, but a few
have to correspond to names referenced in //WorldModelKit//, so:

=
void Actions::translates(wording W, parse_node *p) {
	if (<action-name>(W)) {
		RTActions::translate(<<rp>>, Node::get_text(p));
	} else {
		LOG("Tried action name %W\n", W);
		StandardProblems::sentence_problem(Task::syntax_tree(),
			_p_(PM_TranslatesNonAction),
			"this does not appear to be the name of an action",
			"so cannot be translated into I6 at all.");
		return;
	}
}
