[Inter::Code::] The Code Construct.

Defining the Code construct.

@

@e CODE_IST

=
void Inter::Code::define(void) {
	inter_construct *IC = Inter::Defn::create_construct(
		CODE_IST,
		L"code",
		&Inter::Code::read,
		NULL,
		&Inter::Code::verify,
		&Inter::Code::write,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		I"code", I"codes");
	IC->min_level = 1;
	IC->max_level = 100000000;
	IC->usage_permissions = INSIDE_CODE_PACKAGE;
	IC->children_field = CODE_CODE_IFLD;
	METHOD_ADD(IC, VERIFY_INTER_CHILDREN_MTID, Inter::Code::verify_children);
}

@

@d BLOCK_CODE_IFLD 2
@d CODE_CODE_IFLD 3

@d EXTENT_CODE_IFR 4

=
inter_error_message *Inter::Code::read(inter_reading_state *IRS, inter_line_parse *ilp, inter_error_location *eloc) {
	if (ilp->no_annotations > 0) return Inter::Errors::plain(I"__annotations are not allowed", eloc);

	inter_error_message *E = Inter::Defn::vet_level(IRS, CODE_IST, ilp->indent_level, eloc);
	if (E) return E;

	inter_symbol *routine = Inter::Defn::get_latest_block_symbol();
	if (routine == NULL) return Inter::Errors::plain(I"'code' used outside function", eloc);

	return Inter::Code::new(IRS, routine, ilp->indent_level, eloc);
}

inter_error_message *Inter::Code::new(inter_reading_state *IRS, inter_symbol *routine, int level, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_2(IRS, CODE_IST, 0, Inter::create_frame_list(IRS->read_into), eloc, (inter_t) level);
	inter_error_message *E = Inter::Defn::verify_construct(P); if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

inter_error_message *Inter::Code::verify(inter_frame P) {
	if (P.extent != EXTENT_CODE_IFR) return Inter::Frame::error(&P, I"extent wrong", NULL);
	return NULL;
}

inter_error_message *Inter::Code::write(OUTPUT_STREAM, inter_frame P) {
	WRITE("code");
	return NULL;
}

void Inter::Code::verify_children(inter_construct *IC, inter_frame P, inter_error_message **E) {
	inter_frame_list *ifl = Inter::Defn::list_of_children(P);
	inter_frame C;
	LOOP_THROUGH_INTER_FRAME_LIST(C, ifl) {
		if ((C.data[0] != INV_IST) && (C.data[0] != SPLAT_IST) && (C.data[0] != EVALUATION_IST) && (C.data[0] != LABEL_IST) && (C.data[0] != VAL_IST) && (C.data[0] != COMMENT_IST)) {
			*E = Inter::Frame::error(&C, I"only an inv, a val, a splat, a concatenate or a label can be below a code", NULL);
			return;
		}
	}
}

inter_frame_list *Inter::Code::code_list(inter_symbol *label_name) {
	if (label_name == NULL) return NULL;
	inter_frame D = Inter::Symbols::defining_frame(label_name);
	if (Inter::Frame::valid(&D) == FALSE) return NULL;
	if (D.data[ID_IFLD] != CODE_IST) return NULL;
	return Inter::Defn::list_of_children(D);
}
