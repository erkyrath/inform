[StackedVariables::] Stacked Variables.

To permit variables to have scopes intermediate between local and
global: for example, to be shared by all rules in a given rulebook.

@h Definitions.

=
typedef struct stacked_variable {
	struct wording name; /* text of the name */
	struct parse_node *assigned_at; /* sentence assigning it */
	struct nonlocal_variable *underlying_var; /* the variable in question */
	int owner_id; /* who owns this */
	int offset_in_owning_frame; /* word offset of storage (counts from 0) */
	struct wording match_wording_text; /* matching text (relevant for action variables only) */
	CLASS_DEFINITION
} stacked_variable;

typedef struct stacked_variable_list {
	struct stacked_variable *the_stv; /* the STV */
	struct stacked_variable_list *next; /* in linked list */
	CLASS_DEFINITION
} stacked_variable_list;

typedef struct stacked_variable_owner {
	int no_stvs;
	int recognition_id;
	struct stacked_variable_list *list_of_stvs;
	struct inter_name *stvo_iname;
	CLASS_DEFINITION
} stacked_variable_owner;

typedef struct stacked_variable_owner_list {
	struct stacked_variable_owner *stvo; /* the STO */
	struct stacked_variable_owner_list *next; /* in linked list */
	CLASS_DEFINITION
} stacked_variable_owner_list;

@

= (early code)
int max_frame_size_needed = 0;

@ =
nonlocal_variable_emission StackedVariables::how_to_lvalue(stacked_variable *stv) {
	if ((stv->owner_id == ACTION_PROCESSING_RB) && (stv->offset_in_owning_frame == 0))
		return NonlocalVariables::nve_from_iname(Hierarchy::find(ACTOR_HL));
	else
		return NonlocalVariables::nve_from_mstack(stv->owner_id, stv->offset_in_owning_frame, FALSE);
}

nonlocal_variable_emission StackedVariables::how_to_rvalue(stacked_variable *stv) {
	if ((stv->owner_id == ACTION_PROCESSING_RB) && (stv->offset_in_owning_frame == 0))
		return NonlocalVariables::nve_from_iname(Hierarchy::find(ACTOR_HL));
	else
		return NonlocalVariables::nve_from_mstack(stv->owner_id, stv->offset_in_owning_frame, TRUE);
}

int StackedVariables::get_owner_id(stacked_variable *stv) {
	return stv->owner_id;
}

int StackedVariables::get_offset(stacked_variable *stv) {
	return stv->offset_in_owning_frame;
}

kind *StackedVariables::get_kind(stacked_variable *stv) {
	nonlocal_variable *nlv = StackedVariables::get_variable(stv);
	return NonlocalVariables::kind(nlv);
}

nonlocal_variable *StackedVariables::get_variable(stacked_variable *stv) {
	if (stv == NULL) return NULL;
	return stv->underlying_var;
}

void StackedVariables::set_matching_text(stacked_variable *stv, wording W) {
	stv->match_wording_text = W;
}

wording StackedVariables::get_matching_text(stacked_variable *stv) {
	return stv->match_wording_text;
}

stacked_variable *StackedVariables::parse_match_clause(stacked_variable_owner *stvo,
	wording W) {
	for (stacked_variable_list *stvl = stvo->list_of_stvs; stvl; stvl = stvl->next)
		if (Wordings::starts_with(W, stvl->the_stv->match_wording_text))
			return stvl->the_stv;
	return NULL;
}

stacked_variable_owner *StackedVariables::new_owner(int id) {
	stacked_variable_owner *stvo = CREATE(stacked_variable_owner);
	stvo->recognition_id = id;
	stvo->no_stvs = 0;
	stvo->list_of_stvs = NULL;
	stvo->stvo_iname = NULL;
	return stvo;
}

int StackedVariables::owner_empty(stacked_variable_owner *stvo) {
	if (stvo->no_stvs == 0) return TRUE;
	return FALSE;
}

stacked_variable *StackedVariables::add_empty(stacked_variable_owner *stvo,
	wording W, kind *K) {
	stacked_variable *stv = CREATE(stacked_variable);
	nonlocal_variable *q;
	W = Articles::remove_the(W);
	stv->name = W;
	stv->owner_id = stvo->recognition_id;
	stv->offset_in_owning_frame = stvo->no_stvs++;
	stv->assigned_at = current_sentence;
	stv->match_wording_text = EMPTY_WORDING;
	stvo->list_of_stvs = StackedVariables::add_to_list(stvo->list_of_stvs, stv);
	if (stvo->no_stvs > max_frame_size_needed)
		max_frame_size_needed = stvo->no_stvs;
	q = NonlocalVariables::new_stacked(W, K, stv);
	stv->underlying_var = q;
	NonlocalVariables::set_I6_identifier(q, FALSE, StackedVariables::how_to_rvalue(stv));
	NonlocalVariables::set_I6_identifier(q, TRUE, StackedVariables::how_to_lvalue(stv));
	return stv;
}

stacked_variable_owner_list *StackedVariables::add_owner_to_list(stacked_variable_owner_list *stvol,
	stacked_variable_owner *stvo) {
	stacked_variable_owner_list *ostvol = stvol;

	while (stvol) {
		if (stvol->stvo == stvo) return ostvol;
		stacked_variable_owner_list *nxt = stvol->next;
		if (nxt == NULL) break;
		stvol = nxt;
	}

	stacked_variable_owner_list *nstvol = CREATE(stacked_variable_owner_list);
	nstvol->next = NULL;
	nstvol->stvo = stvo;
	if (stvol == NULL) return nstvol;
	stvol->next = nstvol;
	return ostvol;
}

stacked_variable_owner_list *StackedVariables::append_owner_list(stacked_variable_owner_list *stvol,
	stacked_variable_owner_list *extras) {
	LOGIF(RULEBOOK_COMPILATION,
		"Appending list %08x to list %08x\n", (int) extras, (int) stvol);
	stacked_variable_owner_list *new_head = stvol;
	for (; extras; extras = extras->next)
		new_head = StackedVariables::add_owner_to_list(new_head, extras->stvo);
	return new_head;
}

int StackedVariables::list_length(stacked_variable_list *stvl) {
	int l = 0;
	while (stvl) {
		l++;
		stvl = stvl->next;
	}
	return l;
}

void StackedVariables::index_owner(OUTPUT_STREAM, stacked_variable_owner *stvo) {
	stacked_variable_list *stvl;
	for (stvl=stvo->list_of_stvs; stvl; stvl = stvl->next)
		if ((stvl->the_stv) && (stvl->the_stv->underlying_var)) {
			HTML::open_indented_p(OUT, 2, "tight");
			NonlocalVariables::index_single(OUT, stvl->the_stv->underlying_var);
			HTML_CLOSE("p");
		}
}

stacked_variable *StackedVariables::parse_from_owner_list(stacked_variable_owner_list *stvol, wording W) {
	if (Wordings::empty(W)) return NULL;
	W = Articles::remove_the(W);
	while (stvol) {
		stacked_variable *stv = NULL;
		if (stvol->stvo) stv = StackedVariables::parse_from_list(stvol->stvo->list_of_stvs, W);
		if (stv) return stv;
		stvol = stvol->next;
	}
	return NULL;
}

stacked_variable *StackedVariables::parse_from_list(stacked_variable_list *stvl, wording W) {
	while (stvl) {
		if (Wordings::match(stvl->the_stv->name, W))
			return stvl->the_stv;
		stvl = stvl->next;
	}
	return NULL;
}

stacked_variable_list *StackedVariables::add_to_list(stacked_variable_list *stvl,
	stacked_variable *stv) {
	stacked_variable_list *nstvl = CREATE(stacked_variable_list), *ostvl = stvl;
	nstvl->the_stv = stv;
	nstvl->next = NULL;
	if (stvl == NULL) return nstvl;
	while (stvl->next) stvl = stvl->next;
	stvl->next = nstvl;
	return ostvl;
}

int StackedVariables::compile_frame_creator(stacked_variable_owner *stvo, inter_name *iname) {
	if (stvo == NULL) return 0;

	packaging_state save = Routines::begin(iname);
	inter_symbol *pos_s = LocalVariables::add_named_call_as_symbol(I"pos");
	inter_symbol *state_s = LocalVariables::add_named_call_as_symbol(I"state");

	Produce::inv_primitive(Emit::tree(), IFELSE_BIP);
	Produce::down(Emit::tree());
		Produce::inv_primitive(Emit::tree(), EQ_BIP);
		Produce::down(Emit::tree());
			Produce::val_symbol(Emit::tree(), K_value, state_s);
			Produce::val(Emit::tree(), K_number, LITERAL_IVAL, 1);
		Produce::up(Emit::tree());
		Produce::code(Emit::tree());
		Produce::down(Emit::tree());
			@<Compile frame creator if state is set@>;
		Produce::up(Emit::tree());
		Produce::code(Emit::tree());
		Produce::down(Emit::tree());
			@<Compile frame creator if state is clear@>;
		Produce::up(Emit::tree());
	Produce::up(Emit::tree());

	int count = 0;
	for (stacked_variable_list *stvl = stvo->list_of_stvs; stvl; stvl = stvl->next) count++;

	Produce::inv_primitive(Emit::tree(), RETURN_BIP);
	Produce::down(Emit::tree());
		Produce::val(Emit::tree(), K_number, LITERAL_IVAL, (inter_ti) count);
	Produce::up(Emit::tree());

	Routines::end(save);
	stvo->stvo_iname = iname;
	return count;
}

@<Compile frame creator if state is set@> =
	for (stacked_variable_list *stvl = stvo->list_of_stvs; stvl; stvl = stvl->next) {
		nonlocal_variable *q = StackedVariables::get_variable(stvl->the_stv);
		kind *K = NonlocalVariables::kind(q);
		Produce::inv_primitive(Emit::tree(), STORE_BIP);
		Produce::down(Emit::tree());
			Produce::inv_primitive(Emit::tree(), LOOKUPREF_BIP);
			Produce::down(Emit::tree());
				Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(MSTACK_HL));
				Produce::val_symbol(Emit::tree(), K_value, pos_s);
			Produce::up(Emit::tree());
			if (Kinds::Behaviour::uses_pointer_values(K))
				Kinds::RunTime::emit_heap_allocation(Kinds::RunTime::make_heap_allocation(K, 1, -1));
			else
				NonlocalVariables::emit_initial_value_as_val(q);
		Produce::up(Emit::tree());

		Produce::inv_primitive(Emit::tree(), POSTINCREMENT_BIP);
		Produce::down(Emit::tree());
			Produce::ref_symbol(Emit::tree(), K_value, pos_s);
		Produce::up(Emit::tree());
	}

@<Compile frame creator if state is clear@> =
	for (stacked_variable_list *stvl = stvo->list_of_stvs; stvl; stvl = stvl->next) {
		nonlocal_variable *q = StackedVariables::get_variable(stvl->the_stv);
		kind *K = NonlocalVariables::kind(q);
		if (Kinds::Behaviour::uses_pointer_values(K)) {
			Produce::inv_call_iname(Emit::tree(), Hierarchy::find(BLKVALUEFREE_HL));
			Produce::down(Emit::tree());
				Produce::inv_primitive(Emit::tree(), LOOKUP_BIP);
				Produce::down(Emit::tree());
					Produce::val_iname(Emit::tree(), K_value, Hierarchy::find(MSTACK_HL));
					Produce::val_symbol(Emit::tree(), K_value, pos_s);
				Produce::up(Emit::tree());
			Produce::up(Emit::tree());
		}
		Produce::inv_primitive(Emit::tree(), POSTINCREMENT_BIP);
		Produce::down(Emit::tree());
			Produce::ref_symbol(Emit::tree(), K_value, pos_s);
		Produce::up(Emit::tree());
	}

@ =
inter_name *StackedVariables::frame_creator(stacked_variable_owner *stvo) {
	return stvo->stvo_iname;
}