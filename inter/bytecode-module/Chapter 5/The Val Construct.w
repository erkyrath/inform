[Inter::Val::] The Val Construct.

Defining the val construct.

@

@e VAL_IST

=
void Inter::Val::define(void) {
	inter_construct *IC = InterConstruct::create_construct(VAL_IST, I"val");
	InterConstruct::specify_syntax(IC, I"val TOKENS");
	InterConstruct::allow_in_depth_range(IC, 1, INFINITELY_DEEP);
	InterConstruct::permit(IC, INSIDE_CODE_PACKAGE_ICUP);
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, Inter::Val::read);
	METHOD_ADD(IC, CONSTRUCT_TRANSPOSE_MTID, Inter::Val::transpose);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, Inter::Val::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, Inter::Val::write);
}

@

@d BLOCK_VAL_IFLD 2
@d KIND_VAL_IFLD 3
@d VAL1_VAL_IFLD 4
@d VAL2_VAL_IFLD 5

@d EXTENT_VAL_IFR 6

=
void Inter::Val::read(inter_construct *IC, inter_bookmark *IBM, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	if (SymbolAnnotation::nonempty(&(ilp->set))) { *E = Inter::Errors::plain(I"__annotations are not allowed", eloc); return; }

	*E = InterConstruct::check_level_in_package(IBM, VAL_IST, ilp->indent_level, eloc);
	if (*E) return;

	inter_package *routine = InterBookmark::package(IBM);
	if (routine == NULL) { *E = Inter::Errors::plain(I"'val' used outside function", eloc); return; }
	inter_symbols_table *locals = InterPackage::scope(routine);
	if (locals == NULL) { *E = Inter::Errors::plain(I"function has no symbols table", eloc); return; }

	text_stream *kind_text = NULL, *value_text = ilp->mr.exp[0];
	match_results mr2 = Regexp::create_mr();
	if (Regexp::match(&mr2, value_text, L"%((%c+)%) (%c+)")) {
		kind_text = mr2.exp[0];
		value_text = mr2.exp[1];
	}

	inter_type val_type = InterTypes::parse_simple(InterBookmark::scope(IBM), eloc, kind_text, E);
	if (*E) return;

	inter_ti val1 = 0;
	inter_ti val2 = 0;

	inter_symbol *kind_as_value = TextualInter::find_symbol(IBM, eloc, value_text, TYPENAME_IST, E);
	if (kind_as_value) {
		*E = NULL;
		InterValuePairs::from_symbol(InterBookmark::tree(IBM), InterBookmark::package(IBM), kind_as_value, &val1, &val2);
	} else {
		*E = InterValuePairs::parse(ilp->line, eloc, IBM, val_type, value_text, &val1, &val2, locals);
		if (*E) return;
	}

	*E = Inter::Val::new(IBM, val_type, ilp->indent_level, val1, val2, eloc);
}

inter_error_message *Inter::Val::new(inter_bookmark *IBM, inter_type val_type,
	int level, inter_ti val1, inter_ti val2, inter_error_location *eloc) {
	inter_tree_node *P = Inode::new_with_4_data_fields(IBM, VAL_IST, 0, InterTypes::to_TID_wrt_bookmark(IBM, val_type), val1, val2, eloc, (inter_ti) level);
	inter_error_message *E = InterConstruct::verify_construct(InterBookmark::package(IBM), P); if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

void Inter::Val::transpose(inter_construct *IC, inter_tree_node *P, inter_ti *grid, inter_ti grid_extent, inter_error_message **E) {
	P->W.instruction[VAL2_VAL_IFLD] = InterValuePairs::transpose_value(P->W.instruction[VAL1_VAL_IFLD], P->W.instruction[VAL2_VAL_IFLD], grid, grid_extent, E);
}

void Inter::Val::verify(inter_construct *IC, inter_tree_node *P, inter_package *owner, inter_error_message **E) {
	if (P->W.extent != EXTENT_VAL_IFR) { *E = Inode::error(P, I"extent wrong", NULL); return; }
	Inter::Verify::typed_data(owner, P, KIND_VAL_IFLD, VAL1_VAL_IFLD, E);
}

void Inter::Val::write(inter_construct *IC, OUTPUT_STREAM, inter_tree_node *P, inter_error_message **E) {
	inter_symbols_table *locals = InterPackage::scope_of(P);
	if (locals == NULL) { *E = Inode::error(P, I"function has no symbols table", NULL); return; }
	WRITE("val ");
	InterTypes::write_optional_type_marker(OUT, P, KIND_VAL_IFLD);
	InterValuePairs::write(OUT, P, P->W.instruction[VAL1_VAL_IFLD], P->W.instruction[VAL2_VAL_IFLD], locals, FALSE);
}
