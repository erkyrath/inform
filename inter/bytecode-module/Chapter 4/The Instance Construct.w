[Inter::Instance::] The Instance Construct.

Defining the instance construct.

@

@e INSTANCE_IST

=
void Inter::Instance::define(void) {
	inter_construct *IC = InterConstruct::create_construct(INSTANCE_IST, I"instance");
	InterConstruct::specify_syntax(IC, I"instance IDENTIFIER TOKENS");
	InterConstruct::permit(IC, INSIDE_PLAIN_PACKAGE_ICUP);
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, Inter::Instance::read);
	METHOD_ADD(IC, CONSTRUCT_TRANSPOSE_MTID, Inter::Instance::transpose);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, Inter::Instance::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, Inter::Instance::write);
}

@

@d DEFN_INST_IFLD 2
@d KIND_INST_IFLD 3
@d VAL1_INST_IFLD 4
@d VAL2_INST_IFLD 5
@d PLIST_INST_IFLD 6
@d PERM_LIST_INST_IFLD 7

@d EXTENT_INST_IFR 8

=
void Inter::Instance::read(inter_construct *IC, inter_bookmark *IBM, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	*E = InterConstruct::vet_level(IBM, INSTANCE_IST, ilp->indent_level, eloc);
	if (*E) return;

	if (SymbolAnnotation::nonempty(&(ilp->set))) { *E = Inter::Errors::plain(I"__annotations are not allowed", eloc); return; }

	text_stream *ktext = ilp->mr.exp[1], *vtext = NULL;

	match_results mr2 = Regexp::create_mr();
	if (Regexp::match(&mr2, ktext, L"(%i+) = (%c+)")) { ktext = mr2.exp[0]; vtext = mr2.exp[1]; }

	inter_symbol *inst_name = Inter::Textual::new_symbol(eloc, InterBookmark::scope(IBM), ilp->mr.exp[0], E);
	if (*E) return;
	inter_symbol *inst_kind = Inter::Textual::find_symbol(InterBookmark::tree(IBM), eloc, InterBookmark::scope(IBM), ktext, KIND_IST, E);
	if (*E) return;

	inter_data_type *idt = Inter::Kind::data_type(inst_kind);
	if (Inter::Types::is_enumerated(idt) == FALSE)
		{ *E = Inter::Errors::quoted(I"not a kind which has instances", ilp->mr.exp[1], eloc); return; }

	inter_ti v1 = UNDEF_IVAL, v2 = 0;
	if (vtext) {
		*E = Inter::Types::read(ilp->line, eloc, InterBookmark::tree(IBM), InterBookmark::package(IBM), NULL, vtext, &v1, &v2, InterBookmark::scope(IBM));
		if (*E) return;
	}
	*E = Inter::Instance::new(IBM, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, inst_name), InterSymbolsTable::id_from_symbol_at_bookmark(IBM, inst_kind), v1, v2, (inter_ti) ilp->indent_level, eloc);
}

inter_error_message *Inter::Instance::new(inter_bookmark *IBM, inter_ti SID, inter_ti KID, inter_ti V1, inter_ti V2, inter_ti level, inter_error_location *eloc) {
	inter_warehouse *warehouse = InterBookmark::warehouse(IBM);
	inter_ti L1 = InterWarehouse::create_node_list(warehouse, InterBookmark::package(IBM));
	inter_ti L2 = InterWarehouse::create_node_list(warehouse, InterBookmark::package(IBM));
	inter_tree_node *P = Inode::new_with_6_data_fields(IBM, INSTANCE_IST, SID, KID, V1, V2, L1, L2, eloc, level);
	inter_error_message *E = InterConstruct::verify_construct(InterBookmark::package(IBM), P);
	if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

void Inter::Instance::transpose(inter_construct *IC, inter_tree_node *P, inter_ti *grid, inter_ti grid_extent, inter_error_message **E) {
	P->W.instruction[PLIST_INST_IFLD] = grid[P->W.instruction[PLIST_INST_IFLD]];
	P->W.instruction[PERM_LIST_INST_IFLD] = grid[P->W.instruction[PERM_LIST_INST_IFLD]];
}

void Inter::Instance::verify(inter_construct *IC, inter_tree_node *P, inter_package *owner, inter_error_message **E) {
	if (P->W.extent != EXTENT_INST_IFR) { *E = Inode::error(P, I"extent wrong", NULL); return; }
	*E = Inter::Verify::defn(owner, P, DEFN_INST_IFLD); if (*E) return;
	inter_symbol *inst_name = InterSymbolsTable::symbol_from_ID(InterPackage::scope(owner), P->W.instruction[DEFN_INST_IFLD]);
	*E = Inter::Verify::symbol(owner, P, P->W.instruction[KIND_INST_IFLD], KIND_IST); if (*E) return;
	inter_symbol *inst_kind = InterSymbolsTable::symbol_from_ID(InterPackage::scope(owner), P->W.instruction[KIND_INST_IFLD]);
	inter_data_type *idt = Inter::Kind::data_type(inst_kind);
	if (Inter::Types::is_enumerated(idt)) {
		if (P->W.instruction[VAL1_INST_IFLD] == UNDEF_IVAL) {
			P->W.instruction[VAL1_INST_IFLD] = LITERAL_IVAL;
			P->W.instruction[VAL2_INST_IFLD] = Inter::Kind::next_enumerated_value(inst_kind);
		}
	} else { *E = Inode::error(P, I"not a kind which has instances", NULL); return; }
	*E = Inter::Verify::value(owner, P, VAL1_INST_IFLD, inst_kind); if (*E) return;

	inter_ti vcount = Inode::bump_verification_count(P);
	if (vcount == 0) {
		Inter::Kind::new_instance(inst_kind, inst_name);
	}
}

inter_ti Inter::Instance::permissions_list(inter_symbol *kind_symbol) {
	if (kind_symbol == NULL) return 0;
	inter_tree_node *D = InterSymbol::definition(kind_symbol);
	if (D == NULL) return 0;
	return D->W.instruction[PERM_LIST_INST_IFLD];
}

void Inter::Instance::write(inter_construct *IC, OUTPUT_STREAM, inter_tree_node *P, inter_error_message **E) {
	inter_symbol *inst_name = InterSymbolsTable::symbol_from_ID_at_node(P, DEFN_INST_IFLD);
	inter_symbol *inst_kind = InterSymbolsTable::symbol_from_ID_at_node(P, KIND_INST_IFLD);
	if ((inst_name) && (inst_kind)) {
		inter_data_type *idt = Inter::Kind::data_type(inst_kind);
		if (idt) {
			WRITE("instance %S %S = ", inst_name->symbol_name, inst_kind->symbol_name);
			Inter::Types::write(OUT, P, NULL,
				P->W.instruction[VAL1_INST_IFLD], P->W.instruction[VAL2_INST_IFLD], InterPackage::scope_of(P), FALSE);
		} else { *E = Inode::error(P, I"instance with bad data type", NULL); return; }
	} else { *E = Inode::error(P, I"bad instance", NULL); return; }
	SymbolAnnotation::write_annotations(OUT, P, inst_name);
}

inter_ti Inter::Instance::properties_list(inter_symbol *inst_name) {
	if (inst_name == NULL) return 0;
	inter_tree_node *D = InterSymbol::definition(inst_name);
	if (D == NULL) return 0;
	return D->W.instruction[PLIST_INST_IFLD];
}

inter_symbol *Inter::Instance::kind_of(inter_symbol *inst_name) {
	if (inst_name == NULL) return NULL;
	inter_tree_node *D = InterSymbol::definition(inst_name);
	if (D == NULL) return NULL;
	if (D->W.instruction[ID_IFLD] != INSTANCE_IST) return NULL;
	return InterSymbolsTable::symbol_from_ID_at_node(D, KIND_INST_IFLD);
}
