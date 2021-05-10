[RTRulebooks::] Rulebooks.

To compile the rulebooks submodule for a compilation unit, which contains
_rulebook and _outcome packages.

@h Compilation data.
Each |rulebook| object contains this data:

=
typedef struct rulebook_compilation_data {
	struct package_request *rb_package;
	struct inter_name *rb_id_iname;
	struct inter_name *vars_creator_fn_iname;
	struct parse_node *where_declared;
} rulebook_compilation_data;

@ Note that rulebook packages sometimes live inside scene, action or activity
packages, so they are not always in the rulebooks submodule.

=
rulebook_compilation_data RTRulebooks::new_compilation_data(rulebook *B,
	package_request *P) {
	rulebook_compilation_data rcd;
	rcd.rb_package = P;
	rcd.vars_creator_fn_iname = NULL;
	rcd.rb_id_iname = NULL;
	rcd.where_declared = current_sentence;
	return rcd;
}

package_request *RTRulebooks::package(rulebook *B) {
	if (B->compilation_data.rb_package == NULL)
		B->compilation_data.rb_package =
			Hierarchy::local_package_to(RULEBOOKS_HAP, B->compilation_data.where_declared);
	return B->compilation_data.rb_package;
}

@ Rulebooks are identified at runtime by a unique set of ID numbers, which are
determined at the linking stage.

=
inter_name *RTRulebooks::id_iname(rulebook *B) {
	if (B->compilation_data.rb_id_iname == NULL)
		B->compilation_data.rb_id_iname =
			Hierarchy::make_iname_in(RULEBOOK_ID_HL, RTRulebooks::package(B));
	return B->compilation_data.rb_id_iname;
}

@ The following function creates and initialises any shared variables for the
rulebook:

=
inter_name *RTRulebooks::get_vars_creator_iname(rulebook *B) {
	if (B->compilation_data.vars_creator_fn_iname == NULL)
		B->compilation_data.vars_creator_fn_iname =
			Hierarchy::make_iname_in(RULEBOOK_STV_CREATOR_FN_HL, RTRulebooks::package(B));
	return B->compilation_data.vars_creator_fn_iname;
}

@h Compilation.

=
void RTRulebooks::compile(void) {
	rulebook *B;
	LOOP_OVER(B, rulebook) {
		text_stream *desc = Str::new();
		WRITE_TO(desc, "compile rulebook '%W'", B->primary_name);
		Sequence::queue(&RTRulebooks::compilation_agent, STORE_POINTER_rulebook(B), desc);
	}
}

@ This compiles everything needed for a single rulebook:

=
void RTRulebooks::compilation_agent(compilation_subtask *t) {
	rulebook *B = RETRIEVE_POINTER_rulebook(t->data);
	package_request *P = RTRulebooks::package(B);
	
	inter_name *run_fn_iname = Hierarchy::make_iname_in(RUN_FN_HL, P);
	inter_name *vars_creator_iname = NULL;
	if (SharedVariables::set_empty(B->my_variables) == FALSE)
		vars_creator_iname = RTRulebooks::get_vars_creator_iname(B);
	@<Compile rulebook metadata@>;
	@<Compile rulebook ID constant@>;
	@<Compile run function@>;
	if (vars_creator_iname) @<Compile shared variables creator function@>;
}

@<Compile rulebook metadata@> =
	Hierarchy::apply_metadata_from_wording(P, RULEBOOK_NAME_MD_HL, B->primary_name);
	TEMPORARY_TEXT(PN)
	WRITE_TO(PN, "%+W rulebook", B->primary_name);
	Hierarchy::apply_metadata(P, RULEBOOK_PNAME_MD_HL, PN);
	DISCARD_TEXT(PN)
	Hierarchy::apply_metadata_from_iname(P, RULEBOOK_RUN_FN_MD_HL, run_fn_iname);
	if (vars_creator_iname)
		Hierarchy::apply_metadata_from_iname(P, RULEBOOK_VARC_MD_HL, vars_creator_iname);

@<Compile rulebook ID constant@> =
	Emit::numeric_constant(RTRulebooks::id_iname(B), 0); /* placeholder */

@<Compile shared variables creator function@> =
	RTSharedVariables::compile_creator_fn(B->my_variables, vars_creator_iname);

@<Compile run function@> =
	int action_based = FALSE;
	if (Rulebooks::action_focus(B)) action_based = TRUE;
	if (B->automatically_generated) action_based = FALSE;
	int parameter_based = FALSE;
	if (Rulebooks::action_focus(B) == FALSE) parameter_based = TRUE;
	booking_list *L = B->contents;
	LOGIF(RULEBOOK_COMPILATION, "Compiling rulebook: %W = %n\n",
		B->primary_name, run_fn_iname);

	int countup = BookingLists::length(L);
	if (countup == 0) {
		Emit::iname_constant(run_fn_iname, K_value,
			Hierarchy::find(EMPTY_RULEBOOK_INAME_HL));
	} else {
		@<Compile run function for a nonempty rulebook@>;
	}

@ Grouping is the practice of gathering together rules which all rely on
the same action going on; it's then efficient to test the action once rather
than once for each rule.

@<Compile run function for a nonempty rulebook@> =
	int grouping = TRUE;
	if (action_based == FALSE) grouping = FALSE;

	inter_symbol *forbid_breaks_s = NULL, *rv_s = NULL, *original_deadflag_s = NULL, *p_s = NULL;
	packaging_state save_array = Emit::new_packaging_state();

	@<Open the rulebook compilation@>;
	int group_size = 0, group_started = FALSE, entry_count = 0, action_group_open = FALSE;
	LOOP_OVER_BOOKINGS(br, L) {
		parse_node *spec = Rvalues::from_rule(RuleBookings::get_rule(br));
		if (grouping) {
			if (group_size == 0) {
				if (group_started) @<End an action group in the rulebook@>;
				action_name *an = ActionRules::required_action_for_booking(br);
				booking *brg = br;
				while ((brg) && (an == ActionRules::required_action_for_booking(brg))) {
					group_size++;
					brg = brg->next_booking;
				}
				group_started = TRUE;
				@<Begin an action group in the rulebook@>;
			}
			group_size--;
		}
		@<Compile an entry in the rulebook@>;
		entry_count++;
	}
	if (group_started) @<End an action group in the rulebook@>;
	@<Close the rulebook compilation@>;

@<Open the rulebook compilation@> =
	save_array = Functions::begin(run_fn_iname);
	forbid_breaks_s = LocalVariables::new_other_as_symbol(I"forbid_breaks");
	rv_s = LocalVariables::new_internal_commented_as_symbol(I"rv", I"return value");
	if (countup > 1)
		original_deadflag_s =
			LocalVariables::new_internal_commented_as_symbol(I"original_deadflag", I"saved state");
	if (parameter_based)
		p_s = LocalVariables::new_internal_commented_as_symbol(I"p", I"rulebook parameter");

	RuleBookings::list_judge_ordering(L);
	if (BookingLists::is_empty_of_i7_rules(L) == FALSE)
		RTRulebooks::commentary(L);

	if (countup > 1) {
		EmitCode::inv(STORE_BIP);
		EmitCode::down();
			EmitCode::ref_symbol(K_value, original_deadflag_s);
			EmitCode::val_iname(K_value, Hierarchy::find(DEADFLAG_HL));
		EmitCode::up();
	}
	if (parameter_based) {
		EmitCode::inv(STORE_BIP);
		EmitCode::down();
			EmitCode::ref_symbol(K_value, p_s);
			EmitCode::val_iname(K_value, Hierarchy::find(PARAMETER_VALUE_HL));
		EmitCode::up();
	}

@<Begin an action group in the rulebook@> =
	if (an) {
		EmitCode::inv(IFELSE_BIP);
		EmitCode::down();
			EmitCode::inv(EQ_BIP);
			EmitCode::down();
				EmitCode::val_iname(K_value, Hierarchy::find(ACTION_HL));
				EmitCode::val_iname(K_value, RTActions::double_sharp(an));
			EmitCode::up();
			EmitCode::code();
			EmitCode::down();

		action_group_open = TRUE;
	}

@<Compile an entry in the rulebook@> =
	if (entry_count > 0) {
		EmitCode::inv(IF_BIP);
		EmitCode::down();
			EmitCode::inv(NE_BIP);
			EmitCode::down();
				EmitCode::val_symbol(K_value, original_deadflag_s);
				EmitCode::val_iname(K_value, Hierarchy::find(DEADFLAG_HL));
			EmitCode::up();
			EmitCode::code();
			EmitCode::down();
				EmitCode::inv(RETURN_BIP);
				EmitCode::down();
					EmitCode::val_number(0);
				EmitCode::up();
			EmitCode::up();
		EmitCode::up();
	}
	@<Compile an optional mid-rulebook paragraph break@>;
	if (parameter_based) {
		EmitCode::inv(STORE_BIP);
		EmitCode::down();
			EmitCode::ref_iname(K_value, Hierarchy::find(PARAMETER_VALUE_HL));
			EmitCode::val_symbol(K_value, p_s);
		EmitCode::up();
	}
	EmitCode::inv(STORE_BIP);
	EmitCode::down();
		EmitCode::ref_symbol(K_value, rv_s);
		EmitCode::inv(INDIRECT0_BIP);
		EmitCode::down();
			CompileValues::to_code_val(spec);
		EmitCode::up();
	EmitCode::up();

	EmitCode::inv(IF_BIP);
	EmitCode::down();
		EmitCode::val_symbol(K_value, rv_s);
		EmitCode::code();
		EmitCode::down();
			EmitCode::inv(IF_BIP);
			EmitCode::down();
				EmitCode::inv(EQ_BIP);
				EmitCode::down();
					EmitCode::val_symbol(K_value, rv_s);
					EmitCode::val_number(2);
				EmitCode::up();
				EmitCode::code();
				EmitCode::down();
					EmitCode::inv(RETURN_BIP);
					EmitCode::down();
						EmitCode::val_iname(K_value,
							Hierarchy::find(REASON_THE_ACTION_FAILED_HL));
					EmitCode::up();
				EmitCode::up();
			EmitCode::up();

			EmitCode::inv(RETURN_BIP);
			EmitCode::down();
				CompileValues::to_code_val(spec);
			EmitCode::up();
		EmitCode::up();
	EmitCode::up();

	EmitCode::inv(STORE_BIP);
	EmitCode::down();
		EmitCode::inv(LOOKUPREF_BIP);
		EmitCode::down();
			EmitCode::val_iname(K_value, Hierarchy::find(LATEST_RULE_RESULT_HL));
			EmitCode::val_number(0);
		EmitCode::up();
		EmitCode::val_number(0);
	EmitCode::up();

@<End an action group in the rulebook@> =
	if (action_group_open) {
			EmitCode::up();
			EmitCode::code();
			EmitCode::down();
				@<Compile an optional mid-rulebook paragraph break@>;
			EmitCode::up();
		EmitCode::up();
		action_group_open = FALSE;
	}

@<Close the rulebook compilation@> =
	EmitCode::inv(RETURN_BIP);
	EmitCode::down();
		EmitCode::val_number(0);
	EmitCode::up();
	Functions::end(save_array);

@<Compile an optional mid-rulebook paragraph break@> =
	if (entry_count > 0) {
		EmitCode::inv(IF_BIP);
		EmitCode::down();
			EmitCode::val_iname(K_number, Hierarchy::find(SAY__P_HL));
			EmitCode::code();
			EmitCode::down();
				EmitCode::call(Hierarchy::find(RULEBOOKPARBREAK_HL));
				EmitCode::down();
					EmitCode::val_symbol(K_value, forbid_breaks_s);
				EmitCode::up();
			EmitCode::up();
		EmitCode::up();
	}

@h Commentary on the contents of a rulebook.

=
void RTRulebooks::commentary(booking_list *L) {
	int t = BookingLists::length(L);
	int s = 0;
	LOOP_OVER_BOOKINGS(br, L) {
		s++;
		RTRulebooks::rule_comment(RuleBookings::get_rule(br), s, t);
		if (br->next_booking) {
			TEMPORARY_TEXT(C)
			if (br->placement != br->next_booking->placement) {
				WRITE_TO(C, "--- now the ");
				switch(br->next_booking->placement) {
					case FIRST_PLACEMENT:  WRITE_TO(C, "first-placed rules"); break;
					case MIDDLE_PLACEMENT: WRITE_TO(C, "mid-placed rules"); break;
					case LAST_PLACEMENT:   WRITE_TO(C, "last-placed rules"); break;
				}
				WRITE_TO(C, " ---");
				EmitCode::comment(C);
			} else {
				RuleBookings::comment(C, br);
				if (Str::len(C) > 0) EmitCode::comment(C);
			}
			DISCARD_TEXT(C)
		}
	}
}

@ =
void RTRulebooks::rule_comment(rule *R, int index, int from) {
	TEMPORARY_TEXT(C)
	WRITE_TO(C, "Rule %d/%d", index, from);
	if (R->defn_as_I7_source == NULL) {
		WRITE_TO(C, ": %n", RTRules::iname(R));
	}
	EmitCode::comment(C);
	DISCARD_TEXT(C)
	if (R->defn_as_I7_source) {
		TEMPORARY_TEXT(C)
		WRITE_TO(C, "%~W:", R->defn_as_I7_source->log_text);
		EmitCode::comment(C);
		DISCARD_TEXT(C)
	}
}

@h Rulebook outcomes at runtime.
Each |named_rulebook_outcome| object contains this data:

=
typedef struct nro_compilation_data {
	struct package_request *nro_package;
	struct inter_name *nro_iname;
	int equated_hl;
	struct parse_node *where_declared;
} nro_compilation_data;

@ We are going to have to compile alias constants for a few NROs with special
names, in order that code in kits can see them:

=
<notable-rulebook-outcomes> ::=
	it is very likely |     ==> { RBNO4_INAME_HL, - }
	it is likely |          ==> { RBNO3_INAME_HL, - }
	it is possible |        ==> { RBNO2_INAME_HL, - }
	it is unlikely |        ==> { RBNO1_INAME_HL, - }
	it is very unlikely     ==> { RBNO0_INAME_HL, - }

@ =
nro_compilation_data RTRulebooks::new_nro_compilation_data(named_rulebook_outcome *nro) {
	nro_compilation_data nrocd;
	nrocd.nro_package = NULL;
	nrocd.nro_iname = NULL;
	if (<notable-rulebook-outcomes>(Nouns::nominative_singular(nro->name))) nrocd.equated_hl = <<r>>;
	else nrocd.equated_hl = -1;
	nrocd.where_declared = current_sentence;
	return nrocd;
}

package_request *RTRulebooks::nro_package(named_rulebook_outcome *nro) {
	if (nro->compilation_data.nro_package == NULL)
		nro->compilation_data.nro_package =
			Hierarchy::local_package_to(OUTCOMES_HAP, nro->compilation_data.where_declared);
	return nro->compilation_data.nro_package;
}

inter_name *RTRulebooks::nro_iname(named_rulebook_outcome *nro) {
	if (nro->compilation_data.nro_iname == NULL)
		nro->compilation_data.nro_iname =
			Hierarchy::make_iname_with_memo(OUTCOME_HL,
				RTRulebooks::nro_package(nro), Nouns::nominative_singular(nro->name));
	return nro->compilation_data.nro_iname;
}

@ =
void RTRulebooks::compile_nros(void) {
	named_rulebook_outcome *nro;
	LOOP_OVER(nro, named_rulebook_outcome) {
		text_stream *desc = Str::new();
		WRITE_TO(desc, "named rulebook outcome '%W'", Nouns::nominative_singular(nro->name));
		Sequence::queue(&RTRulebooks::nro_compilation_agent,
			STORE_POINTER_named_rulebook_outcome(nro), desc);
	}
}

@ There is very little actually in one of these packages:

=
void RTRulebooks::nro_compilation_agent(compilation_subtask *t) {
	named_rulebook_outcome *nro = RETRIEVE_POINTER_named_rulebook_outcome(t->data);
	package_request *P = RTRulebooks::nro_package(nro);
	@<Compile the NRO metadata@>;
	@<Compile the NRO value@>;
	if (nro->compilation_data.equated_hl >= 0) @<Compile the alias constant@>;
}

@<Compile the NRO metadata@> =
	Hierarchy::apply_metadata_from_wording(P, OUTCOME_NAME_MD_HL,
		Nouns::nominative_singular(nro->name));

@ Named rulebook outcomes are represented at runtime by literal texts (a very
questionable arrangement, but there it is). 

@<Compile the NRO value@> =
	TEMPORARY_TEXT(RV)
	WRITE_TO(RV, "%+W", Nouns::nominative_singular(nro->name));
	Emit::text_constant(RTRulebooks::nro_iname(nro), RV);
	DISCARD_TEXT(RV)

@<Compile the alias constant@> =
	inter_name *equated_iname =
		Hierarchy::make_iname_in(nro->compilation_data.equated_hl, P);
	Hierarchy::make_available(equated_iname);
	Emit::iname_constant(equated_iname, K_value, RTRulebooks::nro_iname(nro));

@

=
inter_name *RTRulebooks::default_outcome_iname(void) {
	named_rulebook_outcome *nro;
	LOOP_OVER(nro, named_rulebook_outcome)
		return RTRulebooks::nro_iname(nro);
	return NULL;
}

void RTRulebooks::compile_default_outcome(outcomes *outs) {
	int rtrue = FALSE;
	rulebook_outcome *rbo = outs->default_named_outcome;
	if (rbo) {
		switch(rbo->kind_of_outcome) {
			case SUCCESS_OUTCOME: {
				inter_name *iname = Hierarchy::find(RULEBOOKSUCCEEDS_HL);
				EmitCode::call(iname);
				EmitCode::down();
				RTKinds::emit_weak_id_as_val(K_rulebook_outcome);
				EmitCode::val_iname(K_value, RTRulebooks::nro_iname(rbo->outcome_name));
				EmitCode::up();
				rtrue = TRUE;
				break;
			}
			case FAILURE_OUTCOME: {
				inter_name *iname = Hierarchy::find(RULEBOOKFAILS_HL);
				EmitCode::call(iname);
				EmitCode::down();
				RTKinds::emit_weak_id_as_val(K_rulebook_outcome);
				EmitCode::val_iname(K_value, RTRulebooks::nro_iname(rbo->outcome_name));
				EmitCode::up();
				rtrue = TRUE;
				break;
			}
		}
	} else {
		switch(outs->default_rule_outcome) {
			case SUCCESS_OUTCOME: {
				inter_name *iname = Hierarchy::find(RULEBOOKSUCCEEDS_HL);
				EmitCode::call(iname);
				EmitCode::down();
				EmitCode::val_number(0);
				EmitCode::val_number(0);
				EmitCode::up();
				rtrue = TRUE;
				break;
			}
			case FAILURE_OUTCOME: {
				inter_name *iname = Hierarchy::find(RULEBOOKFAILS_HL);
				EmitCode::call(iname);
				EmitCode::down();
				EmitCode::val_number(0);
				EmitCode::val_number(0);
				EmitCode::up();
				rtrue = TRUE;
				break;
			}
		}
	}

	if (rtrue) EmitCode::rtrue();
}

void RTRulebooks::compile_outcome(named_rulebook_outcome *nro) {
	id_body *idb = Functions::defn_being_compiled();
	rulebook_outcome *rbo = FocusAndOutcome::rbo_from_context(nro, idb);
	if (rbo == NULL) {
		rulebook *B;
		LOOP_OVER(B, rulebook) {
			outcomes *outs = Rulebooks::get_outcomes(B);
			rulebook_outcome *ro;
			LOOP_OVER_LINKED_LIST(ro, rulebook_outcome, outs->named_outcomes)
				if (ro->outcome_name == nro) {
					rbo = ro;
					break;
				}
		}
		if (rbo == NULL) internal_error("nro with no rb context");
	}
	switch(rbo->kind_of_outcome) {
		case SUCCESS_OUTCOME: {
			inter_name *iname = Hierarchy::find(RULEBOOKSUCCEEDS_HL);
			EmitCode::call(iname);
			EmitCode::down();
			RTKinds::emit_weak_id_as_val(K_rulebook_outcome);
			EmitCode::val_iname(K_value, RTRulebooks::nro_iname(nro));
			EmitCode::up();
			EmitCode::rtrue();
			break;
		}
		case FAILURE_OUTCOME: {
			inter_name *iname = Hierarchy::find(RULEBOOKFAILS_HL);
			EmitCode::call(iname);
			EmitCode::down();
			RTKinds::emit_weak_id_as_val(K_rulebook_outcome);
			EmitCode::val_iname(K_value, RTRulebooks::nro_iname(nro));
			EmitCode::up();
			EmitCode::rtrue();
			break;
		}
		case NO_OUTCOME:
			EmitCode::rfalse();
			break;
		default:
			internal_error("bad RBO outcome kind");
	}
}

void RTRulebooks::RulebookOutcomePrintingRule(void) {
	inter_name *printing_rule_name = Kinds::Behaviour::get_iname(K_rulebook_outcome);
	packaging_state save = Functions::begin(printing_rule_name);
	inter_symbol *rbnov_s = LocalVariables::new_other_as_symbol(I"nro");
	EmitCode::inv(IFELSE_BIP);
	EmitCode::down();
		EmitCode::inv(EQ_BIP);
		EmitCode::down();
			EmitCode::val_symbol(K_value, rbnov_s);
			EmitCode::val_number(0);
		EmitCode::up();
		EmitCode::code();
		EmitCode::down();
			EmitCode::inv(PRINT_BIP);
			EmitCode::down();
				EmitCode::val_text(I"(no outcome)");
			EmitCode::up();
		EmitCode::up();
		EmitCode::code();
		EmitCode::down();
			EmitCode::inv(PRINTSTRING_BIP);
			EmitCode::down();
				EmitCode::val_symbol(K_value, rbnov_s);
			EmitCode::up();
			EmitCode::rfalse();
		EmitCode::up();
	EmitCode::up();
	Functions::end(save);
}

