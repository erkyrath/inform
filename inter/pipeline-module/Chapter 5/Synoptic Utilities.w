[Synoptic::] Synoptic Utilities.

Utility functions for generating the code in the synoptic module.

@h Dealing with symbols.
We are going to need to read and write these: for reading --

=
inter_symbol *Synoptic::get_symbol(inter_package *pack, text_stream *name) {
	inter_symbol *loc_s =
		InterSymbolsTables::symbol_from_name(Inter::Packages::scope(pack), name);
	if (loc_s == NULL) Metadata::err("package symbol not found", pack, name);
	return loc_s;
}

inter_tree_node *Synoptic::get_definition(inter_package *pack, text_stream *name) {
	inter_symbol *def_s = InterSymbolsTables::symbol_from_name(Inter::Packages::scope(pack), name);
	if (def_s == NULL) {
		LOG("Unable to find symbol %S in $6\n", name, pack);
		internal_error("no symbol");
	}
	inter_tree_node *D = def_s->definition;
	if (D == NULL) {
		LOG("Undefined symbol %S in $6\n", name, pack);
		internal_error("undefined symbol");
	}
	return D;
}

@ To clarify: here, the symbol is optional, that is, need not exist; but if it
does exist, it must have a definition, and we return that.

=
inter_tree_node *Synoptic::get_optional_definition(inter_package *pack, text_stream *name) {
	inter_symbol *def_s = InterSymbolsTables::symbol_from_name(Inter::Packages::scope(pack), name);
	if (def_s == NULL) return NULL;
	inter_tree_node *D = def_s->definition;
	if (D == NULL) internal_error("undefined symbol");
	return D;
}

@ And this creates a new symbol:

=
inter_symbol *Synoptic::new_symbol(inter_package *pack, text_stream *name) {
	return InterSymbolsTables::create_with_unique_name(Inter::Packages::scope(pack), name);
}

@h Making textual constants.

=
void Synoptic::textual_constant(inter_tree *I, pipeline_step *step,
	inter_symbol *con_s, text_stream *S, inter_bookmark *IBM) {
	Inter::Symbols::annotate_i(con_s, TEXT_LITERAL_IANN, 1);
	inter_ti ID = Inter::Warehouse::create_text(InterTree::warehouse(I),
		InterBookmark::package(IBM));
	Str::copy(Inter::Warehouse::get_text(InterTree::warehouse(I), ID), S);
	Produce::guard(Inter::Constant::new_textual(IBM,
		InterSymbolsTables::id_from_symbol(I, InterBookmark::package(IBM), con_s),
		InterSymbolsTables::id_from_symbol(I, InterBookmark::package(IBM),
			RunningPipelines::get_symbol(step, unchecked_kind_RPSYM)),
		ID, (inter_ti) InterBookmark::baseline(IBM) + 1, NULL));
}

@h Making functions.

=
inter_package *synoptic_fn_package = NULL;
packaging_state synoptic_fn_ps;
void Synoptic::begin_function(inter_tree *I, inter_name *iname) {
	synoptic_fn_package = Produce::function_body(I, &synoptic_fn_ps, iname);
}
void Synoptic::end_function(inter_tree *I, pipeline_step *step, inter_name *iname) {
	Produce::end_function_body(I);
	inter_symbol *fn_s = InterNames::define(iname);
	Produce::guard(Inter::Constant::new_function(Packaging::at(I),
		InterSymbolsTables::id_from_symbol(I, InterBookmark::package(Packaging::at(I)), fn_s),
		InterSymbolsTables::id_from_symbol(I, InterBookmark::package(Packaging::at(I)),
			RunningPipelines::get_symbol(step, unchecked_kind_RPSYM)),
		synoptic_fn_package,
		Produce::baseline(Packaging::at(I)), NULL));
	Packaging::exit(I, synoptic_fn_ps);
}

@ To give such a function a local:

=
inter_symbol *Synoptic::local(inter_tree *I, text_stream *name, text_stream *comment) {
	return Produce::local(I, K_value, name, 0, comment);
}

@h Making arrays.

=
inter_tree_node *synoptic_array_node = NULL;
packaging_state synoptic_array_ps;

void Synoptic::begin_array(inter_tree *I, pipeline_step *step, inter_name *iname) {
	synoptic_array_ps = Packaging::enter_home_of(iname);
	inter_symbol *con_s = InterNames::define(iname);
	synoptic_array_node = Inode::fill_3(Packaging::at(I), CONSTANT_IST,
		 InterSymbolsTables::id_from_IRS_and_symbol(Packaging::at(I), con_s),
		 InterSymbolsTables::id_from_IRS_and_symbol(Packaging::at(I),
		 	RunningPipelines::get_symbol(step, list_of_unchecked_kind_RPSYM)),
		 CONSTANT_INDIRECT_LIST, NULL, 
		 (inter_ti) InterBookmark::baseline(Packaging::at(I)) + 1);
}

void Synoptic::end_array(inter_tree *I) {
	inter_error_message *E = Inter::Defn::verify_construct(
		InterBookmark::package(Packaging::at(I)), synoptic_array_node);
	if (E) {
		Inter::Errors::issue(E);
		internal_error("synoptic array failed verification");
	}
	NodePlacement::move_to_moving_bookmark(synoptic_array_node, Packaging::at(I));
	Packaging::exit(I, synoptic_array_ps);
}

@ Three ways to define an entry:

=
void Synoptic::numeric_entry(inter_ti val2) {
	if (Inode::extend(synoptic_array_node, 2) == FALSE) internal_error("cannot extend");
	synoptic_array_node->W.data[synoptic_array_node->W.extent-2] = LITERAL_IVAL;
	synoptic_array_node->W.data[synoptic_array_node->W.extent-1] = val2;
}
void Synoptic::symbol_entry(inter_symbol *S) {
	if (Inode::extend(synoptic_array_node, 2) == FALSE) internal_error("cannot extend");
	inter_package *pack = Inter::Packages::container(synoptic_array_node);
	inter_symbol *local_S =
		InterSymbolsTables::create_with_unique_name(Inter::Packages::scope(pack), S->symbol_name);
	Wiring::wire_to(local_S, S);
	inter_ti val1 = 0, val2 = 0;
	Inter::Symbols::to_data(Inter::Packages::tree(pack), pack, local_S, &val1, &val2);
	synoptic_array_node->W.data[synoptic_array_node->W.extent-2] = ALIAS_IVAL;
	synoptic_array_node->W.data[synoptic_array_node->W.extent-1] = val2;
}
void Synoptic::textual_entry(text_stream *text) {
	if (Inode::extend(synoptic_array_node, 2) == FALSE) internal_error("cannot extend");
	inter_package *pack = Inter::Packages::container(synoptic_array_node);
	inter_tree *I = Inter::Packages::tree(pack);
	inter_ti val2 = Inter::Warehouse::create_text(InterTree::warehouse(I), pack);
	text_stream *glob_storage = Inter::Warehouse::get_text(InterTree::warehouse(I), val2);
	Str::copy(glob_storage, text);
	synoptic_array_node->W.data[synoptic_array_node->W.extent-2] = LITERAL_TEXT_IVAL;
	synoptic_array_node->W.data[synoptic_array_node->W.extent-1] = val2;
}
