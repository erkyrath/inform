[InvInstruction::] The Inv Construct.

Defining the inv construct.

@


=
void InvInstruction::define_construct(void) {
	inter_construct *IC = InterInstruction::create_construct(INV_IST, I"inv");
	InterInstruction::specify_syntax(IC, I"inv TOKEN");
	InterInstruction::fix_instruction_length_between(IC, EXTENT_INV_IFR, EXTENT_INV_IFR);
	InterInstruction::allow_in_depth_range(IC, 1, INFINITELY_DEEP);
	InterInstruction::permit(IC, INSIDE_CODE_PACKAGE_ICUP);
	InterInstruction::permit(IC, CAN_HAVE_CHILDREN_ICUP);
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, InvInstruction::read);
	METHOD_ADD(IC, CONSTRUCT_TRANSPOSE_MTID, InvInstruction::transpose);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, InvInstruction::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, InvInstruction::write);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_CHILDREN_MTID, InvInstruction::verify_children);
}

@

@d BLOCK_INV_IFLD 2
@d METHOD_INV_IFLD 3
@d INVOKEE_INV_IFLD 4

@d EXTENT_INV_IFR 5

@d INVOKED_PRIMITIVE 1
@d INVOKED_ROUTINE 2
@d INVOKED_OPCODE 3

=
void InvInstruction::read(inter_construct *IC, inter_bookmark *IBM, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	inter_package *routine = InterBookmark::package(IBM);
	if (routine == NULL) { *E = InterErrors::plain(I"'inv' used outside function", eloc); return; }

	inter_symbol *invoked_name = InterSymbolsTable::symbol_from_name(InterTree::global_scope(InterBookmark::tree(IBM)), ilp->mr.exp[0]);
	if ((invoked_name == NULL) && (Str::get_first_char(ilp->mr.exp[0]) == '!')) {
		invoked_name = Primitives::declare_one_named(InterBookmark::tree(IBM), &(InterBookmark::tree(IBM)->site.strdata.package_types_bookmark), ilp->mr.exp[0]);
		if (invoked_name == NULL) {
			*E = InterErrors::quoted(I"'inv' on undeclared primitive", ilp->mr.exp[0], eloc); return;
		}
	}
	if (invoked_name == NULL) invoked_name = TextualInter::find_symbol(IBM, eloc, ilp->mr.exp[0], 0, E);
	if (invoked_name == NULL) { *E = InterErrors::quoted(I"'inv' on unknown routine or primitive", ilp->mr.exp[0], eloc); return; }

	if ((InterSymbol::defined_elsewhere(invoked_name)) ||
		(InterSymbol::misc_but_undefined(invoked_name))) {
		*E = InvInstruction::new_call(IBM, invoked_name, (inter_ti) ilp->indent_level, eloc);
		return;
	}
	switch (InterSymbol::definition(invoked_name)->W.instruction[ID_IFLD]) {
		case PRIMITIVE_IST:
			*E = InvInstruction::new_primitive(IBM, invoked_name, (inter_ti) ilp->indent_level, eloc);
			return;
		case CONSTANT_IST:
			if (ConstantInstruction::is_function_body(invoked_name)) {
				*E = InvInstruction::new_call(IBM, invoked_name, (inter_ti) ilp->indent_level, eloc);
				return;
			}
			break;
	}
	*E = InterErrors::quoted(I"not a function or primitive", ilp->mr.exp[0], eloc);
}

inter_error_message *InvInstruction::new_primitive(inter_bookmark *IBM, inter_symbol *invoked_name, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *P = Inode::new_with_3_data_fields(IBM, INV_IST, 0, INVOKED_PRIMITIVE, InterSymbolsTable::id_from_symbol(InterBookmark::tree(IBM), NULL, invoked_name),
		eloc, (inter_ti) level);
	inter_error_message *E = VerifyingInter::instruction(InterBookmark::package(IBM), P);
	if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

inter_error_message *InvInstruction::new_call(inter_bookmark *IBM, inter_symbol *invoked_name, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *P = Inode::new_with_3_data_fields(IBM, INV_IST, 0, INVOKED_ROUTINE, InterSymbolsTable::id_at_bookmark(IBM, invoked_name), eloc, (inter_ti) level);
	inter_error_message *E = VerifyingInter::instruction(InterBookmark::package(IBM), P);
	if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

inter_error_message *InvInstruction::new_assembly(inter_bookmark *IBM, inter_ti opcode_storage, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *P = Inode::new_with_3_data_fields(IBM, INV_IST, 0, INVOKED_OPCODE, opcode_storage, eloc, (inter_ti) level);
	inter_error_message *E = VerifyingInter::instruction(InterBookmark::package(IBM), P);
	if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

void InvInstruction::transpose(inter_construct *IC, inter_tree_node *P, inter_ti *grid, inter_ti grid_extent, inter_error_message **E) {
	if (P->W.instruction[METHOD_INV_IFLD] == INVOKED_OPCODE)
		P->W.instruction[INVOKEE_INV_IFLD] = grid[P->W.instruction[INVOKEE_INV_IFLD]];
}

void InvInstruction::verify(inter_construct *IC, inter_tree_node *P, inter_package *owner, inter_error_message **E) {
	switch (P->W.instruction[METHOD_INV_IFLD]) {
		case INVOKED_PRIMITIVE:
			*E = VerifyingInter::GSID_field(P, INVOKEE_INV_IFLD, PRIMITIVE_IST); if (*E) return;
			break;
		case INVOKED_OPCODE:
		case INVOKED_ROUTINE:
			break;
		default:
			*E = Inode::error(P, I"bad invocation method", NULL);
			break;
	}
}

void InvInstruction::write(inter_construct *IC, OUTPUT_STREAM, inter_tree_node *P, inter_error_message **E) {
	switch (P->W.instruction[METHOD_INV_IFLD]) {
		case INVOKED_PRIMITIVE: {
			inter_symbol *invokee = InvInstruction::invokee(P);
			if (invokee) {
				WRITE("inv %S", InterSymbol::identifier(invokee));
			} else { *E = Inode::error(P, I"cannot write inv", NULL); return; }
			break;
		}
		case INVOKED_OPCODE:
			WRITE("inv %S", Inode::ID_to_text(P, P->W.instruction[INVOKEE_INV_IFLD]));
			break;
		case INVOKED_ROUTINE: {
			inter_symbol *invokee = InvInstruction::invokee(P);
			if (invokee) {
				WRITE("inv ");
				TextualInter::write_symbol_from(OUT, P, INVOKEE_INV_IFLD);
			} else { *E = Inode::error(P, I"cannot write inv", NULL); return; }
			break;
		}
	}
}

inter_symbol *InvInstruction::invokee(inter_tree_node *P) {
	if (P->W.instruction[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)
		return InterSymbolsTable::global_symbol_from_ID_at_node(P, INVOKEE_INV_IFLD);
 	return InterSymbolsTable::symbol_from_ID_at_node(P, INVOKEE_INV_IFLD);
}

void InvInstruction::verify_children(inter_construct *IC, inter_tree_node *P, inter_error_message **E) {
	int arity_as_invoked=0;
	LOOP_THROUGH_INTER_CHILDREN(C, P) arity_as_invoked++;
	if ((InvInstruction::arity(P) != -1) &&
		(InvInstruction::arity(P) != arity_as_invoked)) {
		inter_tree *I = P->tree;
		inter_symbol *invokee = InvInstruction::invokee(P);
		if (Primitives::is_BIP_for_indirect_call_returning_value(Primitives::to_BIP(I, invokee))) {
			inter_symbol *better = Primitives::from_BIP(I, Primitives::BIP_for_indirect_call_returning_value(arity_as_invoked - 1));
			P->W.instruction[INVOKEE_INV_IFLD] = InterSymbolsTable::id_from_global_symbol(Inode::tree(P), better);
		} else if (Primitives::is_BIP_for_void_indirect_call(Primitives::to_BIP(I, invokee))) {
			inter_symbol *better = Primitives::from_BIP(I, Primitives::BIP_for_void_indirect_call(arity_as_invoked - 1));
			P->W.instruction[INVOKEE_INV_IFLD] = InterSymbolsTable::id_from_global_symbol(Inode::tree(P), better);
		}
	}
	if ((InvInstruction::arity(P) != -1) &&
		(InvInstruction::arity(P) != arity_as_invoked)) {
		inter_symbol *invokee = InvInstruction::invokee(P);
		text_stream *err = Str::new();
		WRITE_TO(err, "this inv of %S should have %d argument(s), but has %d",
			(invokee)?(InterSymbol::identifier(invokee)):I"<unknown>", InvInstruction::arity(P), arity_as_invoked);
		*E = Inode::error(P, err, NULL);
		return;
	}
	int i=0;
	LOOP_THROUGH_INTER_CHILDREN(C, P) {
		i++;
		if (C->W.instruction[0] == SPLAT_IST) continue;
		if ((C->W.instruction[0] != INV_IST) && (C->W.instruction[0] != REF_IST) && (C->W.instruction[0] != LAB_IST) &&
			(C->W.instruction[0] != CODE_IST) && (C->W.instruction[0] != VAL_IST) && (C->W.instruction[0] != EVALUATION_IST) &&
			(C->W.instruction[0] != REFERENCE_IST) && (C->W.instruction[0] != CAST_IST) && (C->W.instruction[0] != SPLAT_IST) &&
			(C->W.instruction[0] != COMMENT_IST) && (C->W.instruction[0] != ASSEMBLY_IST)) {
			*E = Inode::error(P, I"only inv, ref, cast, splat, lab, assembly, code, concatenate and val can be under an inv", NULL);
			return;
		}
		inter_ti cat_as_invoked = InvInstruction::evaluated_category(C);
		inter_ti cat_needed = InvInstruction::operand_category(P, i-1);
		if ((cat_as_invoked != cat_needed) && (P->W.instruction[METHOD_INV_IFLD] != INVOKED_OPCODE)) {
			inter_symbol *invokee = InvInstruction::invokee(P);
			text_stream *err = Str::new();
			WRITE_TO(err, "operand %d of inv '%S' should be %s, but this is %s",
				i, (invokee)?(InterSymbol::identifier(invokee)):I"<unknown>",
				InvInstruction::cat_name(cat_needed), InvInstruction::cat_name(cat_as_invoked));
			*E = Inode::error(C, err, NULL);
			return;
		}
	}
}

inter_symbol *InvInstruction::read_primitive(inter_tree *I, inter_tree_node *P) {
	if ((P->W.instruction[ID_IFLD] == INV_IST) &&
		(P->W.instruction[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)) {
		return InterSymbolsTable::symbol_from_ID(InterTree::global_scope(I),
			P->W.instruction[INVOKEE_INV_IFLD]);
	}
	return NULL;
}

void InvInstruction::write_primitive(inter_tree *I, inter_tree_node *P, inter_symbol *prim) {
	if ((P->W.instruction[ID_IFLD] == INV_IST) &&
		(P->W.instruction[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)) {
		P->W.instruction[INVOKEE_INV_IFLD] = InterSymbolsTable::id_from_symbol(I, NULL, prim);
	} else internal_error("wrote primitive to non-primitive invocation");
}

char *InvInstruction::cat_name(inter_ti cat) {
	switch (cat) {
		case REF_PRIM_CAT: return "ref";
		case VAL_PRIM_CAT: return "val";
		case LAB_PRIM_CAT: return "lab";
		case CODE_PRIM_CAT: return "code";
		case 0: return "void";
	}
	return "<unknown>";
}

int InvInstruction::arity(inter_tree_node *P) {
	inter_symbol *invokee = InvInstruction::invokee(P);
	switch (P->W.instruction[METHOD_INV_IFLD]) {
		case INVOKED_PRIMITIVE:
			return PrimitiveInstruction::arity(invokee);
		case INVOKED_ROUTINE:
			return -1;
		case INVOKED_OPCODE:
			return -1;
	}
	return 0;
}

inter_ti InvInstruction::evaluated_category(inter_tree_node *P) {
	if (P->W.instruction[0] == REF_IST) return REF_PRIM_CAT;
	if (P->W.instruction[0] == VAL_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == EVALUATION_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == REFERENCE_IST) return REF_PRIM_CAT;
	if (P->W.instruction[0] == CAST_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == LAB_IST) return LAB_PRIM_CAT;
	if (P->W.instruction[0] == CODE_IST) return CODE_PRIM_CAT;
	if (P->W.instruction[0] == ASSEMBLY_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == INV_IST) {
		inter_symbol *invokee = InvInstruction::invokee(P);
		if (P->W.instruction[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)
			return PrimitiveInstruction::result_category(invokee);
		return VAL_PRIM_CAT;
	}
	internal_error("impossible operand");
	return 0;
}

inter_ti InvInstruction::operand_category(inter_tree_node *P, int i) {
	if (P->W.instruction[0] == REF_IST) return REF_PRIM_CAT;
	if (P->W.instruction[0] == VAL_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == EVALUATION_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == REFERENCE_IST) return REF_PRIM_CAT;
	if (P->W.instruction[0] == CAST_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == LAB_IST) return LAB_PRIM_CAT;
	if (P->W.instruction[0] == ASSEMBLY_IST) return VAL_PRIM_CAT;
	if (P->W.instruction[0] == INV_IST) {
		inter_symbol *invokee = InvInstruction::invokee(P);
		if (P->W.instruction[METHOD_INV_IFLD] == INVOKED_PRIMITIVE)
			return PrimitiveInstruction::operand_category(invokee, i);
		return VAL_PRIM_CAT;
	}
	internal_error("impossible operand");
	return 0;
}
