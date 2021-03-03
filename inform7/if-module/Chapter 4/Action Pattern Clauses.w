[APClauses::] Action Pattern Clauses.

Pattern-matches on individual nouns in an action are called clauses.

@

@e ACTOR_AP_CLAUSE from 1
@e NOUN_AP_CLAUSE
@e SECOND_AP_CLAUSE
@e IN_AP_CLAUSE
@e IN_THE_PRESENCE_OF_AP_CLAUSE
@e WHEN_AP_CLAUSE

@e GOING_FROM_AP_CLAUSE
@e GOING_TO_AP_CLAUSE
@e GOING_THROUGH_AP_CLAUSE
@e GOING_BY_AP_CLAUSE
@e PUSHING_AP_CLAUSE

=
typedef struct ap_clause {
	int clause_ID;
	struct stacked_variable *stv_to_match;
	struct parse_node *clause_spec;
	int clause_options;
	struct ap_clause *next;
	CLASS_DEFINITION
} ap_clause;

@ The clause options are a bitmap. Some are meaningful only for one or two
clauses.

@d ALLOW_REGION_AS_ROOM_APCOPT 1
@d DO_NOT_VALIDATE_APCOPT 2
@d TEST_BY_HAND_APCOPT 4

@ =
int APClauses::opt(ap_clause *apoc, int opt) {
	return (((apoc) && (apoc->clause_options)) & opt)?TRUE:FALSE;
}

void APClauses::set_opt(ap_clause *apoc, int opt) {
	if (apoc == NULL) internal_error("no such apoc");
	apoc->clause_options |= opt;
}

void APClauses::clear_opt(ap_clause *apoc, int opt) {
	if (apoc == NULL) internal_error("no such apoc");
	if (apoc->clause_options & opt) apoc->clause_options -= opt;
}

parse_node *APClauses::get_actor(action_pattern *ap) {
	return APClauses::get_val(ap, ACTOR_AP_CLAUSE);
}

void APClauses::set_actor(action_pattern *ap, parse_node *val) {
	APClauses::set_val(ap, ACTOR_AP_CLAUSE, val);
}

parse_node *APClauses::get_noun(action_pattern *ap) {
	return APClauses::get_val(ap, NOUN_AP_CLAUSE);
}

void APClauses::set_noun(action_pattern *ap, parse_node *val) {
	APClauses::set_val(ap, NOUN_AP_CLAUSE, val);
}

parse_node *APClauses::get_second(action_pattern *ap) {
	return APClauses::get_val(ap, SECOND_AP_CLAUSE);
}

void APClauses::set_second(action_pattern *ap, parse_node *val) {
	APClauses::set_val(ap, SECOND_AP_CLAUSE, val);
}

parse_node *APClauses::get_presence(action_pattern *ap) {
	return APClauses::get_val(ap, IN_THE_PRESENCE_OF_AP_CLAUSE);
}

void APClauses::set_presence(action_pattern *ap, parse_node *val) {
	APClauses::set_val(ap, IN_THE_PRESENCE_OF_AP_CLAUSE, val);
}

parse_node *APClauses::get_room(action_pattern *ap) {
	return APClauses::get_val(ap, IN_AP_CLAUSE);
}

void APClauses::set_room(action_pattern *ap, parse_node *val) {
	APClauses::set_val(ap, IN_AP_CLAUSE, val);
}

parse_node *APClauses::get_val(action_pattern *ap, int C) {
	ap_clause *apoc = APClauses::clause(ap, C);
	return (apoc)?(apoc->clause_spec):NULL;
}

void APClauses::set_val(action_pattern *ap, int C, parse_node *val) {
	if (val == NULL) {
		ap_clause *apoc = APClauses::clause(ap, C);
		if (apoc) apoc->clause_spec = val;
	} else {
		ap_clause *apoc = APClauses::ensure_clause(ap, C);
		apoc->clause_spec = val;
	}
}

void APClauses::nullify_nonspecific(action_pattern *ap, int C) {
	ap_clause *apoc = APClauses::clause(ap, C);
	if (apoc) apoc->clause_spec = ActionPatterns::nullify_nonspecific_references(apoc->clause_spec);
}

ap_clause *APClauses::clause(action_pattern *ap, int C) {
	return APClauses::find_clause(ap, C, FALSE);
}

ap_clause *APClauses::ensure_clause(action_pattern *ap, int C) {
	return APClauses::find_clause(ap, C, TRUE);
}

ap_clause *APClauses::find_clause(action_pattern *ap, int C, int make) {
	if (ap) {
		ap_clause *last = NULL;
		for (ap_clause *apoc = ap->ap_clauses; apoc; apoc = apoc->next) {
			if (apoc->clause_ID == C) return apoc;
			if (apoc->clause_ID > C) {
				if (make) @<Make a new clause@>
				else return NULL;
			}
			last = apoc;
		}
		if (make) {
			ap_clause *apoc = NULL;
			@<Make a new clause@>;
		}
	} else {
		if (make) internal_error("cannot make clause in null AP");
	}
	return NULL;
}

@<Make a new clause@> =
	ap_clause *new_apoc = CREATE(ap_clause);
	new_apoc->clause_ID = C;
	new_apoc->stv_to_match = NULL;
	new_apoc->clause_spec = NULL;
	new_apoc->clause_options = 0;
	if (last == NULL) ap->ap_clauses = new_apoc; else last->next = new_apoc;
	new_apoc->next = apoc;
	return new_apoc;

@ =
void APClauses::ap_add_optional_clause(action_pattern *ap, stacked_variable *stv,
	wording W) {
	if (stv == NULL) internal_error("no stacked variable for apoc");
	parse_node *spec = ParseActionPatterns::verified_action_parameter(W);
	int oid = StackedVariables::get_owner_id(stv);
	int off = StackedVariables::get_offset(stv);
	
	int C = 1000*oid + off, ar = FALSE, byhand = FALSE;
	if (oid == 20007 /* i.e., going */ ) {
		switch (off) {
			case 0: C = GOING_FROM_AP_CLAUSE; ar = TRUE; byhand = TRUE; break;
			case 1: C = GOING_TO_AP_CLAUSE; ar = TRUE; byhand = TRUE; break;
			case 2: C = GOING_THROUGH_AP_CLAUSE; byhand = TRUE; break;
			case 3: C = GOING_BY_AP_CLAUSE; byhand = TRUE; break;
			case 4: C = PUSHING_AP_CLAUSE; byhand = TRUE; break;
		}
	}

	ap_clause *apoc = APClauses::ensure_clause(ap, C);
	apoc->stv_to_match = stv;
	apoc->clause_spec = spec;
	if (ar) APClauses::set_opt(apoc, ALLOW_REGION_AS_ROOM_APCOPT);
	if (byhand) APClauses::set_opt(apoc, TEST_BY_HAND_APCOPT);
}

int APClauses::has_stv_clauses(action_pattern *ap) {
	if ((ap) && (APClauses::nudge_to_stv_apoc(ap->ap_clauses))) return TRUE;
	return FALSE;
}

int APClauses::compare_specificity_of_apoc_list(action_pattern *ap1, action_pattern *ap2) {
	int rct1 = APClauses::ap_count_optional_clauses(ap1);
	int rct2 = APClauses::ap_count_optional_clauses(ap2);

	if (rct1 > rct2) return 1;
	if (rct1 < rct2) return -1;
	if (rct1 == 0) return 0;

	ap_clause *apoc1 = APClauses::nudge_to_stv_apoc(ap1->ap_clauses),
		*apoc2 = APClauses::nudge_to_stv_apoc(ap2->ap_clauses);
	while ((apoc1) && (apoc2)) {
		int off1 = StackedVariables::get_offset(apoc1->stv_to_match);
		int off2 = StackedVariables::get_offset(apoc2->stv_to_match);
		if (off1 == off2) {
			int rv = Specifications::compare_specificity(apoc1->clause_spec, apoc2->clause_spec, NULL);
			if (rv != 0) return rv;
			apoc1 = APClauses::nudge_to_stv_apoc(apoc1->next);
			apoc2 = APClauses::nudge_to_stv_apoc(apoc2->next);
		}
		if (off1 < off2) apoc1 = APClauses::nudge_to_stv_apoc(apoc1->next);
		if (off1 > off2) apoc2 = APClauses::nudge_to_stv_apoc(apoc2->next);
	}
	return 0;
}

int APClauses::ap_count_optional_clauses(action_pattern *ap) {
	int n = 0;
	if (ap)
		for (ap_clause *apoc = APClauses::nudge_to_stv_apoc(ap->ap_clauses); apoc;
			apoc = APClauses::nudge_to_stv_apoc(apoc->next))
			n++;
	return n;
}

ap_clause *APClauses::nudge_to_stv_apoc(ap_clause *apoc) {
	while ((apoc) && ((apoc->stv_to_match == NULL) ||
		(APClauses::opt(apoc, TEST_BY_HAND_APCOPT) == FALSE))) apoc = apoc->next;
	return apoc;
}

int APClauses::validate(ap_clause *apoc, kind *K) {
	if ((apoc) &&
		(APClauses::opt(apoc, DO_NOT_VALIDATE_APCOPT) == FALSE) &&
		(Dash::validate_parameter(apoc->clause_spec, K) == FALSE))
		return FALSE;
	return TRUE;
}
