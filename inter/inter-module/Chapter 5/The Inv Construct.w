[Inter::Inv::] The Inv Construct.

Defining the inv construct.

@

@e INV_IST

=
void Inter::Inv::define(void) {
	inter_construct *IC = Inter::Defn::create_construct(
		INV_IST,
		L"inv (%C+)",
		I"inv", I"invs");
	IC->min_level = 1;
	IC->max_level = 100000000;
	IC->usage_permissions = INSIDE_CODE_PACKAGE;
	IC->children_field = OPERANDS_INV_IFLD;
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, Inter::Inv::read);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, Inter::Inv::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, Inter::Inv::write);
	METHOD_ADD(IC, VERIFY_INTER_CHILDREN_MTID, Inter::Inv::verify_children);
}

@

@d BLOCK_INV_IFLD 2
@d METHOD_INV_IFLD 3
@d INVOKEE_INV_IFLD 4
@d OPERANDS_INV_IFLD 5

@d EXTENT_INV_IFR 6

@d INVOKED_PRIMITIVE 1
@d INVOKED_ROUTINE 2
@d INVOKED_OPCODE 3

=
void Inter::Inv::read(inter_construct *IC, inter_reading_state *IRS, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	if (ilp->no_annotations > 0) { *E = Inter::Errors::plain(I"__annotations are not allowed", eloc); return; }
	*E = Inter::Defn::vet_level(IRS, INV_IST, ilp->indent_level, eloc);
	if (*E) return;

	inter_symbol *routine = Inter::Defn::get_latest_block_symbol();
	if (routine == NULL) { *E = Inter::Errors::plain(I"'inv' used outside function", eloc); return; }

	inter_symbol *invoked_name = Inter::SymbolsTables::symbol_from_name(Inter::get_global_symbols(IRS->read_into), ilp->mr.exp[0]);
	if (invoked_name == NULL) invoked_name = Inter::SymbolsTables::symbol_from_name(Inter::Bookmarks::scope(IRS), ilp->mr.exp[0]);
	if (invoked_name == NULL) { *E = Inter::Errors::quoted(I"'inv' on unknown routine or primitive", ilp->mr.exp[0], eloc); return; }

	if ((Inter::Symbols::is_extern(invoked_name)) ||
		(Inter::Symbols::is_predeclared(invoked_name))) {
		*E = Inter::Inv::new_call(IRS, routine, invoked_name, (inter_t) ilp->indent_level, eloc);
		return;
	}
	switch (Inter::Symbols::defining_frame(invoked_name).data[ID_IFLD]) {
		case PRIMITIVE_IST:
			*E = Inter::Inv::new_primitive(IRS, routine, invoked_name, (inter_t) ilp->indent_level, eloc);
			return;
		case CONSTANT_IST:
			if (Inter::Constant::is_routine(invoked_name)) {
				*E = Inter::Inv::new_call(IRS, routine, invoked_name, (inter_t) ilp->indent_level, eloc);
				return;
			}
			break;
	}
	*E = Inter::Errors::quoted(I"not a function or primitive", ilp->mr.exp[0], eloc);
}

inter_error_message *Inter::Inv::new_primitive(inter_reading_state *IRS, inter_symbol *routine, inter_symbol *invoked_name, inter_t level, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_4(IRS, INV_IST, 0, INVOKED_PRIMITIVE, Inter::SymbolsTables::id_from_symbol(IRS->read_into, NULL, invoked_name),
		Inter::create_frame_list(IRS->read_into), eloc, (inter_t) level);
	inter_error_message *E = Inter::Defn::verify_construct(P);
	if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

inter_error_message *Inter::Inv::new_call(inter_reading_state *IRS, inter_symbol *routine, inter_symbol *invoked_name, inter_t level, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_4(IRS, INV_IST, 0, INVOKED_ROUTINE, Inter::SymbolsTables::id_from_IRS_and_symbol(IRS, invoked_name), Inter::create_frame_list(IRS->read_into), eloc, (inter_t) level);
	inter_error_message *E = Inter::Defn::verify_construct(P);
	if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

inter_error_message *Inter::Inv::new_assembly(inter_reading_state *IRS, inter_symbol *routine, inter_t opcode_storage, inter_t level, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_4(IRS, INV_IST, 0, INVOKED_OPCODE, opcode_storage, Inter::create_frame_list(IRS->read_into), eloc, (inter_t) level);
	inter_error_message *E = Inter::Defn::verify_construct(P);
	if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

void Inter::Inv::verify(inter_construct *IC, inter_frame P, inter_error_message **E) {
	if (P.extent != EXTENT_INV_IFR) { *E = Inter::Frame::error(&P, I"extent wrong", NULL); return; }
	inter_symbols_table *locals = Inter::Packages::scope_of(P);
	if (locals == NULL) { *E = Inter::Frame::error(&P, I"function has no symbols table", NULL); return; }

	switch (P.data[METHOD_INV_IFLD]) {
		case INVOKED_PRIMITIVE:
			*E = Inter::Verify::global_symbol(P, P.data[INVOKEE_INV_IFLD], PRIMITIVE_IST); if (*E) return;
			break;
		case INVOKED_OPCODE:
		case INVOKED_ROUTINE:
			break;
		default:
			*E = Inter::Frame::error(&P, I"bad invocation method", NULL);
			break;
	}
}

void Inter::Inv::write(inter_construct *IC, OUTPUT_STREAM, inter_frame P, inter_error_message **E) {
	if (P.data[METHOD_INV_IFLD] == INVOKED_OPCODE) {
		WRITE("inv %S", Inter::get_text(P.repo_segment->owning_repo, P.data[INVOKEE_INV_IFLD]));
	} else {
		inter_symbol *invokee = Inter::Inv::invokee(P);
		if (invokee) {
			WRITE("inv %S", invokee->symbol_name);
		} else { *E = Inter::Frame::error(&P, I"cannot write inv", NULL); return; }
	}
}

inter_symbol *Inter::Inv::invokee(inter_frame P) {
	if (P.data[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)
		return Inter::SymbolsTables::global_symbol_from_frame_data(P, INVOKEE_INV_IFLD);
 	return Inter::SymbolsTables::symbol_from_frame_data(P, INVOKEE_INV_IFLD);
}

void Inter::Inv::verify_children(inter_construct *IC, inter_frame P, inter_error_message **E) {
//	if (P.data[METHOD_INV_IFLD] == INVOKED_ROUTINE) {
//		*E = Inter::Verify::symbol(P, P.data[INVOKEE_INV_IFLD], CONSTANT_IST);
//		if (*E) return;
//	}
	inter_repository *I = P.repo_segment->owning_repo;
	inter_frame_list *ifl = Inter::find_frame_list(I, P.data[OPERANDS_INV_IFLD]);
	int arity_as_invoked = Inter::size_of_frame_list(ifl);
	#ifdef CORE_MODULE
	if ((Inter::Inv::arity(P) != -1) &&
		(Inter::Inv::arity(P) != arity_as_invoked)) {
		inter_symbol *invokee = Inter::Inv::invokee(P);
		if (Primitives::is_indirect_interp(invokee)) {
			inter_symbol *better = Primitives::indirect_interp(arity_as_invoked - 1);
			P.data[INVOKEE_INV_IFLD] = Inter::SymbolsTables::id_from_symbol(I, NULL, better);
		} else if (Primitives::is_indirectv_interp(invokee)) {
			inter_symbol *better = Primitives::indirectv_interp(arity_as_invoked - 1);
			P.data[INVOKEE_INV_IFLD] = Inter::SymbolsTables::id_from_symbol(I, NULL, better);
		}
	}
	#endif
	if ((Inter::Inv::arity(P) != -1) &&
		(Inter::Inv::arity(P) != arity_as_invoked)) {
		inter_symbol *invokee = Inter::Inv::invokee(P);
		text_stream *err = Str::new();
		WRITE_TO(err, "this inv of %S should have %d argument(s), but has %d",
			(invokee)?(invokee->symbol_name):I"<unknown>", Inter::Inv::arity(P), arity_as_invoked);
		*E = Inter::Frame::error(&P, err, NULL);
		return;
	}
	int i=0;
	inter_frame C;
	LOOP_THROUGH_INTER_FRAME_LIST(C, ifl) {
		i++;
		if (C.data[0] == SPLAT_IST) continue;
		if ((C.data[0] != INV_IST) && (C.data[0] != REF_IST) && (C.data[0] != LAB_IST) &&
			(C.data[0] != CODE_IST) && (C.data[0] != VAL_IST) && (C.data[0] != EVALUATION_IST) &&
			(C.data[0] != REFERENCE_IST) && (C.data[0] != CAST_IST) && (C.data[0] != SPLAT_IST) && (C.data[0] != COMMENT_IST)) {
			*E = Inter::Frame::error(&P, I"only inv, ref, cast, splat, lab, code, concatenate and val can be under an inv", NULL);
			return;
		}
		inter_t cat_as_invoked = Inter::Inv::evaluated_category(C);
		inter_t cat_needed = Inter::Inv::operand_category(P, i-1);
		if ((cat_as_invoked != cat_needed) && (P.data[METHOD_INV_IFLD] != INVOKED_OPCODE)) {
			inter_symbol *invokee = Inter::Inv::invokee(P);
			text_stream *err = Str::new();
			WRITE_TO(err, "operand %d of inv '%S' should be %s, but this is %s",
				i, (invokee)?(invokee->symbol_name):I"<unknown>",
				Inter::Inv::cat_name(cat_needed), Inter::Inv::cat_name(cat_as_invoked));
			*E = Inter::Frame::error(&C, err, NULL);
			return;
		}
	}
}

char *Inter::Inv::cat_name(inter_t cat) {
	switch (cat) {
		case REF_PRIM_CAT: return "ref";
		case VAL_PRIM_CAT: return "val";
		case LAB_PRIM_CAT: return "lab";
		case CODE_PRIM_CAT: return "code";
		case 0: return "void";
	}
	return "<unknown>";
}

int Inter::Inv::arity(inter_frame P) {
	inter_symbol *invokee = Inter::Inv::invokee(P);
	switch (P.data[METHOD_INV_IFLD]) {
		case INVOKED_PRIMITIVE:
			return Inter::Primitive::arity(invokee);
		case INVOKED_ROUTINE:
			return -1;
		case INVOKED_OPCODE:
			return -1;
	}
	return 0;
}

inter_t Inter::Inv::evaluated_category(inter_frame P) {
	if (P.data[0] == REF_IST) return REF_PRIM_CAT;
	if (P.data[0] == VAL_IST) return VAL_PRIM_CAT;
	if (P.data[0] == EVALUATION_IST) return VAL_PRIM_CAT;
	if (P.data[0] == REFERENCE_IST) return REF_PRIM_CAT;
	if (P.data[0] == CAST_IST) return VAL_PRIM_CAT;
	if (P.data[0] == LAB_IST) return LAB_PRIM_CAT;
	if (P.data[0] == CODE_IST) return CODE_PRIM_CAT;
	if (P.data[0] == INV_IST) {
		inter_symbol *invokee = Inter::Inv::invokee(P);
		if (P.data[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)
			return Inter::Primitive::result_category(invokee);
		return VAL_PRIM_CAT;
	}
	internal_error("impossible operand");
	return 0;
}

inter_t Inter::Inv::operand_category(inter_frame P, int i) {
	if (P.data[0] == REF_IST) return REF_PRIM_CAT;
	if (P.data[0] == VAL_IST) return VAL_PRIM_CAT;
	if (P.data[0] == EVALUATION_IST) return VAL_PRIM_CAT;
	if (P.data[0] == REFERENCE_IST) return REF_PRIM_CAT;
	if (P.data[0] == CAST_IST) return VAL_PRIM_CAT;
	if (P.data[0] == LAB_IST) return LAB_PRIM_CAT;
	if (P.data[0] == INV_IST) {
		inter_symbol *invokee = Inter::Inv::invokee(P);
		if (P.data[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)
			return Inter::Primitive::operand_category(invokee, i);
		return VAL_PRIM_CAT;
	}
	internal_error("impossible operand");
	return 0;
}
