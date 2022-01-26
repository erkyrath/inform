[Inter::PackageType::] The PackageType Construct.

Defining the packagetype construct.

@

@e PACKAGETYPE_IST

=
void Inter::PackageType::define(void) {
	inter_construct *IC = Inter::Defn::create_construct(
		PACKAGETYPE_IST,
		L"packagetype (_%i+)",
		I"packagetype", I"packagetypes");
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, Inter::PackageType::read);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, Inter::PackageType::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, Inter::PackageType::write);
	IC->usage_permissions = OUTSIDE_OF_PACKAGES;
}

@

@d DEFN_PTYPE_IFLD 2

@d EXTENT_PTYPE_IFR 3

=
void Inter::PackageType::read(inter_construct *IC, inter_bookmark *IBM, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	*E = Inter::Defn::vet_level(IBM, PACKAGETYPE_IST, ilp->indent_level, eloc);
	if (*E) return;

	if (Inter::Annotations::exist(&(ilp->set))) { *E = Inter::Errors::plain(I"__annotations are not allowed", eloc); return; }

	inter_symbol *ptype_name = Inter::Textual::new_symbol(eloc, InterBookmark::scope(IBM), ilp->mr.exp[0], E);
	if (*E) return;

	*E = Inter::PackageType::new_packagetype(IBM, ptype_name, (inter_ti) ilp->indent_level, eloc);
}

inter_error_message *Inter::PackageType::new_packagetype(inter_bookmark *IBM, inter_symbol *ptype, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *P = Inode::fill_1(IBM, PACKAGETYPE_IST, InterSymbolsTables::id_from_IRS_and_symbol(IBM, ptype), eloc, level);
	inter_error_message *E = Inter::Defn::verify_construct(InterBookmark::package(IBM), P);
	if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

void Inter::PackageType::verify(inter_construct *IC, inter_tree_node *P, inter_package *owner, inter_error_message **E) {
	if (P->W.extent < EXTENT_PTYPE_IFR) { *E = Inode::error(P, I"package extent wrong", NULL); return; }
	*E = Inter::Verify::defn(owner, P, DEFN_PTYPE_IFLD);
}

void Inter::PackageType::write(inter_construct *IC, OUTPUT_STREAM, inter_tree_node *P, inter_error_message **E) {
	inter_symbol *ptype_name = InterSymbolsTables::symbol_from_frame_data(P, DEFN_PTYPE_IFLD);
	if (ptype_name) WRITE("packagetype %S", ptype_name->symbol_name);
	else { *E = Inode::error(P, I"cannot write packagetype", NULL); return; }
}
