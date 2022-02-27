[Inter::Constant::] The Constant Construct.

Defining the constant construct.

@

@e CONSTANT_IST

=
void Inter::Constant::define(void) {
	inter_construct *IC = InterConstruct::create_construct(CONSTANT_IST, I"constant");
	InterConstruct::defines_symbol_in_fields(IC, DEFN_CONST_IFLD, KIND_CONST_IFLD);
	InterConstruct::specify_syntax(IC, I"constant TOKENS = TOKENS");
	InterConstruct::fix_instruction_length_between(IC, 4, UNLIMITED_INSTRUCTION_FRAME_LENGTH);
	InterConstruct::permit(IC, INSIDE_PLAIN_PACKAGE_ICUP);
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, Inter::Constant::read);
	METHOD_ADD(IC, CONSTRUCT_TRANSPOSE_MTID, Inter::Constant::transpose);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, Inter::Constant::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, Inter::Constant::write);
}

@

@d DEFN_CONST_IFLD 2
@d KIND_CONST_IFLD 3
@d FORMAT_CONST_IFLD 4
@d DATA_CONST_IFLD 5

@d CONSTANT_DIRECT 0
@d CONSTANT_INDIRECT_LIST 1
@d CONSTANT_SUM_LIST 2
@d CONSTANT_PRODUCT_LIST 3
@d CONSTANT_DIFFERENCE_LIST 4
@d CONSTANT_QUOTIENT_LIST 5
@d CONSTANT_INDIRECT_TEXT 6
@d CONSTANT_ROUTINE 7
@d CONSTANT_STRUCT 8
@d CONSTANT_TABLE 9

=
void Inter::Constant::read(inter_construct *IC, inter_bookmark *IBM, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	*E = InterConstruct::check_level_in_package(IBM, CONSTANT_IST, ilp->indent_level, eloc);
	if (*E) return;

	text_stream *kind_text = NULL, *name_text = ilp->mr.exp[0];
	match_results mr3 = Regexp::create_mr();
	if (Regexp::match(&mr3, name_text, L"%((%c+)%) (%c+)")) {
		kind_text = mr3.exp[0];
		name_text = mr3.exp[1];
	}

	inter_type con_type = InterTypes::parse_simple(InterBookmark::scope(IBM), eloc, kind_text, E);
	if (*E) return;

	inter_symbol *con_name = TextualInter::new_symbol(eloc, InterBookmark::scope(IBM), name_text, E);
	if (*E) return;

	SymbolAnnotation::copy_set_to_symbol(&(ilp->set), con_name);

	text_stream *S = ilp->mr.exp[1];

	match_results mr2 = Regexp::create_mr();
	inter_ti op = 0;
	if (Regexp::match(&mr2, S, L"sum{ (%c*) }")) op = CONSTANT_SUM_LIST;
	else if (Regexp::match(&mr2, S, L"product{ (%c*) }")) op = CONSTANT_PRODUCT_LIST;
	else if (Regexp::match(&mr2, S, L"difference{ (%c*) }")) op = CONSTANT_DIFFERENCE_LIST;
	else if (Regexp::match(&mr2, S, L"quotient{ (%c*) }")) op = CONSTANT_QUOTIENT_LIST;
	if (op != 0) {
		inter_tree_node *P =
			Inode::new_with_3_data_fields(IBM, CONSTANT_IST, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), op, eloc, (inter_ti) ilp->indent_level);
		*E = Inter::Verify::instruction(InterBookmark::package(IBM), P);
		if (*E) return;
		text_stream *conts = mr2.exp[0];
		match_results mr3 = Regexp::create_mr();
		while (Regexp::match(&mr3, conts, L"(%c*?), (%c+)")) {
			if (Inter::Constant::append(ilp->line, eloc, IBM, con_type, P, mr3.exp[0], E) == FALSE)
				return;
			Str::copy(conts, mr3.exp[1]);
		}
		if (Regexp::match(&mr3, conts, L" *(%c*?) *")) {
			if (Inter::Constant::append(ilp->line, eloc, IBM, con_type, P, mr3.exp[0], E) == FALSE)
				return;
		}
		NodePlacement::move_to_moving_bookmark(P, IBM);
		return;
	}

	if (Regexp::match(&mr2, S, L"{ }")) {
		inter_ti form = CONSTANT_INDIRECT_LIST;
		inter_tree_node *P =
			Inode::new_with_3_data_fields(IBM, CONSTANT_IST, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), form, eloc, (inter_ti) ilp->indent_level);
		*E = Inter::Verify::instruction(InterBookmark::package(IBM), P);
		if (*E) return;
		NodePlacement::move_to_moving_bookmark(P, IBM);
		return;
	}

	if (Regexp::match(&mr2, S, L"{ (%c*) }")) {
		inter_type conts_type = InterTypes::type_operand(con_type, 0);
		inter_ti form = CONSTANT_INDIRECT_LIST;
		inter_tree_node *P =
			Inode::new_with_3_data_fields(IBM, CONSTANT_IST, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), form, eloc, (inter_ti) ilp->indent_level);
		*E = Inter::Verify::instruction(InterBookmark::package(IBM), P);
		if (*E) return;
		text_stream *conts = mr2.exp[0];
		match_results mr3 = Regexp::create_mr();
		while (Regexp::match(&mr3, conts, L"(%c*?), (%c+)")) {
			if (Inter::Constant::append(ilp->line, eloc, IBM, conts_type, P, mr3.exp[0], E) == FALSE)
				return;
			Str::copy(conts, mr3.exp[1]);
		}
		if (Regexp::match(&mr3, conts, L" *(%c*?) *")) {
			if (Inter::Constant::append(ilp->line, eloc, IBM, conts_type, P, mr3.exp[0], E) == FALSE)
				return;
		}
		NodePlacement::move_to_moving_bookmark(P, IBM);
		return;
	}

	if (Regexp::match(&mr2, S, L"struct{ (%c*) }")) {
		inter_tree_node *P =
			 Inode::new_with_3_data_fields(IBM, CONSTANT_IST, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), CONSTANT_STRUCT, eloc, (inter_ti) ilp->indent_level);
		int arity = InterTypes::type_arity(con_type);
		int counter = 0;
		text_stream *conts = mr2.exp[0];
		match_results mr3 = Regexp::create_mr();
		while (Regexp::match(&mr3, conts, L"(%c*?), (%c+)")) {
			inter_type conts_type = InterTypes::type_operand(con_type, counter++);
			if (Inter::Constant::append(ilp->line, eloc, IBM, conts_type, P, mr3.exp[0], E) == FALSE)
				return;
			Str::copy(conts, mr3.exp[1]);
		}
		if (Regexp::match(&mr3, conts, L" *(%c*?) *")) {
			inter_type conts_type = InterTypes::type_operand(con_type, counter++);
			if (Inter::Constant::append(ilp->line, eloc, IBM, conts_type, P, mr3.exp[0], E) == FALSE)
				return;
		}
		if (counter != arity)
			{ *E = Inter::Errors::quoted(I"wrong size", S, eloc); return; }
		*E = Inter::Verify::instruction(InterBookmark::package(IBM), P); if (*E) return;
		NodePlacement::move_to_moving_bookmark(P, IBM);
		return;
	}

	if (Regexp::match(&mr2, S, L"table{ (%c*) }")) {
		inter_tree_node *P =
			Inode::new_with_3_data_fields(IBM, CONSTANT_IST, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), CONSTANT_TABLE, eloc, (inter_ti) ilp->indent_level);
		*E = Inter::Verify::instruction(InterBookmark::package(IBM), P);
		if (*E) return;
		text_stream *conts = mr2.exp[0];
		match_results mr3 = Regexp::create_mr();
		while (Regexp::match(&mr3, conts, L"(%c*?), (%c+)")) {
			if (Inter::Constant::append(ilp->line, eloc, IBM, InterTypes::untyped(), P, mr3.exp[0], E) == FALSE)
				return;
			Str::copy(conts, mr3.exp[1]);
		}
		if (Regexp::match(&mr3, conts, L" *(%c*?) *")) {
			if (Inter::Constant::append(ilp->line, eloc, IBM, InterTypes::untyped(), P, mr3.exp[0], E) == FALSE)
				return;
		}
		NodePlacement::move_to_moving_bookmark(P, IBM);
		return;
	}

	if ((Str::begins_with_wide_string(S, L"\"")) && (Str::ends_with_wide_string(S, L"\""))) {
		TEMPORARY_TEXT(parsed_text)
		*E = Inter::Constant::parse_text(parsed_text, S, 1, Str::len(S)-2, eloc);
		inter_ti ID = 0;
		if (*E == NULL) {
			ID = InterWarehouse::create_text(InterBookmark::warehouse(IBM), InterBookmark::package(IBM));
			Str::copy(InterWarehouse::get_text(InterBookmark::warehouse(IBM), ID), parsed_text);
		}
		DISCARD_TEXT(parsed_text)
		if (*E) return;
		*E = Inter::Constant::new_textual(IBM, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), ID, (inter_ti) ilp->indent_level, eloc);
		return;
	}

	if (Regexp::match(&mr2, S, L"function (%c*)")) {
		text_stream *fname = mr2.exp[0];
		inter_package *block = InterPackage::from_name(InterBookmark::package(IBM), fname);
		if (block == NULL) {
			*E = Inter::Errors::quoted(I"no such function body", fname, eloc); return;
		}
		*E = Inter::Constant::new_function(IBM, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), block, (inter_ti) ilp->indent_level, eloc);
		return;
	}

	inter_pair val = InterValuePairs::undef();
	*E = InterValuePairs::parse(ilp->line, eloc, IBM, con_type, S, &val, InterBookmark::scope(IBM));
	if (*E) return;

	*E = Inter::Constant::new_numerical(IBM, InterSymbolsTable::id_from_symbol_at_bookmark(IBM, con_name), InterTypes::to_TID_wrt_bookmark(IBM, con_type), val, (inter_ti) ilp->indent_level, eloc);
}

inter_error_message *Inter::Constant::parse_text(text_stream *parsed_text, text_stream *S, int from, int to, inter_error_location *eloc) {
	inter_error_message *E = NULL;
	int literal_mode = FALSE;
	LOOP_THROUGH_TEXT(pos, S) {
		if ((pos.index < from) || (pos.index > to)) continue;
		int c = (int) Str::get(pos);
		if (literal_mode == FALSE) {
			if (c == '\\') { literal_mode = TRUE; continue; }
		} else {
			switch (c) {
				case '\\': break;
				case '"': break;
				case 't': c = 9; break;
				case 'n': c = 10; break;
				default: E = Inter::Errors::plain(I"no such backslash escape", eloc); break;
			}
		}
		if (Inter::Constant::char_acceptable(c) == FALSE) E = Inter::Errors::quoted(I"bad character in text", S, eloc);
		PUT_TO(parsed_text, c);
		literal_mode = FALSE;
	}
	if (E) Str::clear(parsed_text);
	return E;
}

void Inter::Constant::write_text(OUTPUT_STREAM, text_stream *S) {
	LOOP_THROUGH_TEXT(P, S) {
		wchar_t c = Str::get(P);
		if (c == 9) { WRITE("\\t"); continue; }
		if (c == 10) { WRITE("\\n"); continue; }
		if (c == '"') { WRITE("\\\""); continue; }
		if (c == '\\') { WRITE("\\\\"); continue; }
		PUT(c);
	}
}

inter_error_message *Inter::Constant::new_numerical(inter_bookmark *IBM, inter_ti SID, inter_ti KID, inter_pair val, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *P = Inode::new_with_5_data_fields(IBM,
		CONSTANT_IST, SID, KID, CONSTANT_DIRECT, InterValuePairs::to_word1(val), InterValuePairs::to_word2(val), eloc, level);
	inter_error_message *E = Inter::Verify::instruction(InterBookmark::package(IBM), P); if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

inter_error_message *Inter::Constant::new_textual(inter_bookmark *IBM, inter_ti SID, inter_ti KID, inter_ti TID, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *P = Inode::new_with_4_data_fields(IBM,
		CONSTANT_IST, SID, KID, CONSTANT_INDIRECT_TEXT, TID, eloc, level);
	inter_error_message *E = Inter::Verify::instruction(InterBookmark::package(IBM), P); if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

inter_error_message *Inter::Constant::new_function(inter_bookmark *IBM, inter_ti SID, inter_ti KID, inter_package *block, inter_ti level, inter_error_location *eloc) {
	inter_ti BID = block->resource_ID;
	inter_tree_node *P = Inode::new_with_4_data_fields(IBM,
		CONSTANT_IST, SID, KID, CONSTANT_ROUTINE, BID, eloc, level);
	inter_error_message *E = Inter::Verify::instruction(InterBookmark::package(IBM), P); if (E) return E;
	NodePlacement::move_to_moving_bookmark(P, IBM);
	return NULL;
}

inter_error_message *Inter::Constant::new_list(inter_bookmark *IBM, inter_ti SID, inter_ti KID,
	int no_pairs, inter_pair *val_array, inter_ti level, inter_error_location *eloc) {
	inter_tree_node *AP = Inode::new_with_3_data_fields(IBM, CONSTANT_IST, SID, KID, CONSTANT_INDIRECT_LIST, eloc, level);
	int pos = AP->W.extent;
	Inode::extend_instruction_by(AP, (inter_ti) (2*no_pairs));
	for (int i=0; i<no_pairs; i++, pos += 2)
		InterValuePairs::set(AP, pos, val_array[i]);
	inter_error_message *E = Inter::Verify::instruction(InterBookmark::package(IBM), AP); if (E) return E;
	NodePlacement::move_to_moving_bookmark(AP, IBM);
	return NULL;
}

int Inter::Constant::append(text_stream *line, inter_error_location *eloc, inter_bookmark *IBM, inter_type conts_type, inter_tree_node *P, text_stream *S, inter_error_message **E) {
	*E = NULL;
	inter_pair val = InterValuePairs::undef();
	*E = InterValuePairs::parse(line, eloc, IBM, conts_type, S, &val, InterBookmark::scope(IBM));
	if (*E) return FALSE;
	Inode::extend_instruction_by(P, 2);
	InterValuePairs::set(P, P->W.extent-2, val);
	return TRUE;
}

void Inter::Constant::transpose(inter_construct *IC, inter_tree_node *P, inter_ti *grid, inter_ti grid_extent, inter_error_message **E) {
	if (P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_ROUTINE)
		P->W.instruction[DATA_CONST_IFLD] = grid[P->W.instruction[DATA_CONST_IFLD]];

	switch (P->W.instruction[FORMAT_CONST_IFLD]) {
		case CONSTANT_DIRECT:
			InterValuePairs::set(P, DATA_CONST_IFLD,
				InterValuePairs::transpose(InterValuePairs::get(P, DATA_CONST_IFLD), grid, grid_extent, E));
			break;
		case CONSTANT_INDIRECT_TEXT:
			P->W.instruction[DATA_CONST_IFLD] = grid[P->W.instruction[DATA_CONST_IFLD]];
			break;
		case CONSTANT_SUM_LIST:
		case CONSTANT_PRODUCT_LIST:
		case CONSTANT_DIFFERENCE_LIST:
		case CONSTANT_QUOTIENT_LIST:
		case CONSTANT_INDIRECT_LIST:
		case CONSTANT_STRUCT:
		case CONSTANT_TABLE:
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				InterValuePairs::set(P, i,
					InterValuePairs::transpose(InterValuePairs::get(P, i), grid, grid_extent, E));
			}
			break;
	}
}

void Inter::Constant::verify(inter_construct *IC, inter_tree_node *P, inter_package *owner, inter_error_message **E) {
	*E = Inter::Verify::TID_field(owner, P, KIND_CONST_IFLD);
	if (*E) return;
	inter_type it = InterTypes::from_TID_in_field(P, KIND_CONST_IFLD);
	switch (P->W.instruction[FORMAT_CONST_IFLD]) {
		case CONSTANT_DIRECT:
			if (P->W.extent != DATA_CONST_IFLD + 2) { *E = Inode::error(P, I"extent wrong", NULL); return; }
			*E = Inter::Verify::data_pair_fields(owner, P, DATA_CONST_IFLD, it);
			if (*E) return;
			break;
		case CONSTANT_SUM_LIST:
		case CONSTANT_PRODUCT_LIST:
		case CONSTANT_DIFFERENCE_LIST:
		case CONSTANT_QUOTIENT_LIST:
			if ((P->W.extent % 2) != 1) { *E = Inode::error(P, I"extent wrong", NULL); return; }
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				*E = Inter::Verify::data_pair_fields(owner, P, i, it);
				if (*E) return;
			}
			break;
		case CONSTANT_TABLE:
			if ((P->W.extent % 2) != 1) { *E = Inode::error(P, I"extent wrong", NULL); return; }
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				inter_pair val = InterValuePairs::get(P, i);
				inter_symbol *symb = InterValuePairs::symbol_from_data_pair(val, InterPackage::scope(owner));
				if (symb) {
					inter_type type = InterTypes::of_symbol(symb);
					inter_ti constructor = InterTypes::constructor_code(type);
					if ((constructor != COLUMN_ITCONC) && (constructor != UNCHECKED_ITCONC)) {
						*E = Inode::error(P, I"not a table column constant", NULL); return;
					}
				} else {
					*E = Inode::error(P, I"not a table column constant", NULL); return;
				}
			}
			break;
		case CONSTANT_INDIRECT_LIST: {
			if ((P->W.extent % 2) != 1) { *E = Inode::error(P, I"extent wrong", NULL); return; }
			inter_type conts_type = InterTypes::type_operand(it, 0);
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				*E = Inter::Verify::data_pair_fields(owner, P, i, conts_type); if (*E) return;
			}
			break;
		}
		case CONSTANT_STRUCT: {
			if ((P->W.extent % 2) != 1) { *E = Inode::error(P, I"extent odd", NULL); return; }
			int arity = InterTypes::type_arity(it);
			int given = (P->W.extent - DATA_CONST_IFLD)/2;
			if (arity != given) { *E = Inode::error(P, I"extent not same size as struct definition", NULL); return; }
			for (int i=DATA_CONST_IFLD, counter = 0; i<P->W.extent; i=i+2) {
				inter_type conts_type = InterTypes::type_operand(it, counter++);
				*E = Inter::Verify::data_pair_fields(owner, P, i, conts_type); if (*E) return;
			}
			break;
		}
		case CONSTANT_INDIRECT_TEXT:
			if (P->W.extent != DATA_CONST_IFLD + 1) { *E = Inode::error(P, I"extent wrong", NULL); return; }
			inter_ti ID = P->W.instruction[DATA_CONST_IFLD];
			text_stream *S = Inode::ID_to_text(P, ID);
			if (S == NULL) { *E = Inode::error(P, I"no text in comment", NULL); return; }
			LOOP_THROUGH_TEXT(pos, S)
				if (Inter::Constant::char_acceptable(Str::get(pos)) == FALSE)
					{ *E = Inode::error(P, I"bad character in text", NULL); return; }
			break;
		case CONSTANT_ROUTINE:
			if (P->W.extent != DATA_CONST_IFLD + 1) { *E = Inode::error(P, I"extent wrong", NULL); return; }
			break;
	}
}

void Inter::Constant::write(inter_construct *IC, OUTPUT_STREAM, inter_tree_node *P, inter_error_message **E) {
	inter_symbol *con_name = InterSymbolsTable::symbol_from_ID_at_node(P, DEFN_CONST_IFLD);
	int hex = FALSE;
	if (SymbolAnnotation::get_b(con_name, HEX_IANN)) hex = TRUE;
	if (con_name) {
		WRITE("constant ");
		InterTypes::write_optional_type_marker(OUT, P, KIND_CONST_IFLD);
		WRITE("%S = ", InterSymbol::identifier(con_name));
		switch (P->W.instruction[FORMAT_CONST_IFLD]) {
			case CONSTANT_DIRECT:
				InterValuePairs::write(OUT, P, InterValuePairs::get(P, DATA_CONST_IFLD), InterPackage::scope_of(P), hex);
				break;
			case CONSTANT_TABLE:			
			case CONSTANT_SUM_LIST:			
			case CONSTANT_PRODUCT_LIST:
			case CONSTANT_DIFFERENCE_LIST:
			case CONSTANT_QUOTIENT_LIST:
			case CONSTANT_INDIRECT_LIST: {
				if (P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_TABLE) WRITE("table");
				if (P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_SUM_LIST) WRITE("sum");
				if (P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_PRODUCT_LIST) WRITE("product");
				if (P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_DIFFERENCE_LIST) WRITE("difference");
				if (P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_QUOTIENT_LIST) WRITE("quotient");
				WRITE("{");
				for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
					if (i > DATA_CONST_IFLD) WRITE(",");
					WRITE(" ");
					InterValuePairs::write(OUT, P, InterValuePairs::get(P, i), InterPackage::scope_of(P), hex);
				}
				WRITE(" }");
				break;
			}
			case CONSTANT_STRUCT: {
				WRITE("struct{");
				for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
					if (i > DATA_CONST_IFLD) WRITE(",");
					WRITE(" ");
					InterValuePairs::write(OUT, P, InterValuePairs::get(P, i), InterPackage::scope_of(P), hex);
				}
				WRITE(" }");
				break;
			}
			case CONSTANT_INDIRECT_TEXT:
				WRITE("\"");
				inter_ti ID = P->W.instruction[DATA_CONST_IFLD];
				text_stream *S = Inode::ID_to_text(P, ID);
				Inter::Constant::write_text(OUT, S);
				WRITE("\"");
				break;
			case CONSTANT_ROUTINE: {
				inter_package *block = Inode::ID_to_package(P, P->W.instruction[DATA_CONST_IFLD]);
				WRITE("function %S", InterPackage::name(block));
				break;
			}
		}
		SymbolAnnotation::write_annotations(OUT, P, con_name);
	} else {
		*E = Inode::error(P, I"constant can't be written", NULL);
		return;
	}
}

inter_package *Inter::Constant::code_block(inter_symbol *con_symbol) {
	if (con_symbol == NULL) return NULL;
	inter_tree_node *D = InterSymbol::definition(con_symbol);
	if (D == NULL) return NULL;
	if (D->W.instruction[ID_IFLD] != CONSTANT_IST) return NULL;
	if (D->W.instruction[FORMAT_CONST_IFLD] != CONSTANT_ROUTINE) return NULL;
	return Inode::ID_to_package(D, D->W.instruction[DATA_CONST_IFLD]);
}

int Inter::Constant::is_routine(inter_symbol *con_symbol) {
	if (con_symbol == NULL) return FALSE;
	inter_tree_node *D = InterSymbol::definition(con_symbol);
	if (D == NULL) return FALSE;
	if (D->W.instruction[ID_IFLD] != CONSTANT_IST) return FALSE;
	if (D->W.instruction[FORMAT_CONST_IFLD] != CONSTANT_ROUTINE) return FALSE;
	return TRUE;
}

inter_symbols_table *Inter::Constant::local_symbols(inter_symbol *con_symbol) {
	return InterPackage::scope(Inter::Constant::code_block(con_symbol));
}

int Inter::Constant::char_acceptable(int c) {
	if ((c < 0x20) && (c != 0x09) && (c != 0x0a)) return FALSE;
	return TRUE;
}

int Inter::Constant::constant_depth(inter_symbol *con) {
	LOG_INDENT;
	int d = Inter::Constant::constant_depth_r(con);
	LOGIF(CONSTANT_DEPTH_CALCULATION, "%S has depth %d\n", InterSymbol::identifier(con), d);
	LOG_OUTDENT;
	return d;
}
int Inter::Constant::constant_depth_r(inter_symbol *con) {
	if (con == NULL) return 1;
	inter_tree_node *D = InterSymbol::definition(con);
	if (D->W.instruction[ID_IFLD] != CONSTANT_IST) return 1;
	if (D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_DIRECT) {
		inter_pair val = InterValuePairs::get(D, DATA_CONST_IFLD);
		if (InterValuePairs::holds_symbol(val)) {
			inter_symbol *alias =
				InterValuePairs::symbol_from_data_pair(val,
					InterPackage::scope(D->package));
			return Inter::Constant::constant_depth(alias) + 1;
		}
		return 1;
	}
	if ((D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_SUM_LIST) ||
		(D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_PRODUCT_LIST) ||
		(D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_DIFFERENCE_LIST) ||
		(D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_QUOTIENT_LIST)) {
		int total = 0;
		for (int i=DATA_CONST_IFLD; i<D->W.extent; i=i+2) {
			inter_pair val = InterValuePairs::get(D, i);
			if (InterValuePairs::holds_symbol(val)) {
				inter_symbol *alias =
					InterValuePairs::symbol_from_data_pair(val,
						InterPackage::scope(D->package));
				total += Inter::Constant::constant_depth(alias);
			} else total++;
		}
		return 1 + total;
	}
	return 1;
}

inter_ti Inter::Constant::evaluate(inter_symbols_table *T, inter_pair val) {
	if (InterValuePairs::is_number(val)) return InterValuePairs::to_number(val);
	if (InterValuePairs::holds_symbol(val)) {
		inter_symbol *aliased = InterValuePairs::symbol_from_data_pair(val, T);
		if (aliased == NULL) internal_error("bad aliased symbol");
		inter_tree_node *D = aliased->definition;
		if (D == NULL) internal_error("undefined symbol");
		switch (D->W.instruction[FORMAT_CONST_IFLD]) {
			case CONSTANT_DIRECT: {
				inter_pair dval = InterValuePairs::get(D, DATA_CONST_IFLD);
				inter_ti e = Inter::Constant::evaluate(InterPackage::scope_of(D), dval);
				return e;
			}
			case CONSTANT_SUM_LIST:
			case CONSTANT_PRODUCT_LIST:
			case CONSTANT_DIFFERENCE_LIST:
			case CONSTANT_QUOTIENT_LIST: {
				inter_ti result = 0;
				for (int i=DATA_CONST_IFLD; i<D->W.extent; i=i+2) {
					inter_pair operand = InterValuePairs::get(D, i);
					inter_ti extra = Inter::Constant::evaluate(InterPackage::scope_of(D), operand);
					if (i == DATA_CONST_IFLD) result = extra;
					else {
						if (D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_SUM_LIST) result = result + extra;
						if (D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_PRODUCT_LIST) result = result * extra;
						if (D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_DIFFERENCE_LIST) result = result - extra;
						if (D->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_QUOTIENT_LIST) result = result / extra;
					}
				}
				return result;
			}
		}
	}
	return 0;
}

int Inter::Constant::evaluate_to_int(inter_symbol *S) {
	inter_tree_node *P = InterSymbol::definition(S);
	if ((P) &&
		(P->W.instruction[ID_IFLD] == CONSTANT_IST) &&
		(P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_DIRECT)) {
		inter_pair val = InterValuePairs::get(P, DATA_CONST_IFLD);
		if (InterValuePairs::is_number(val))
			return (int) InterValuePairs::to_number(val);
		if (InterValuePairs::holds_symbol(val)) {
			inter_symbols_table *scope = S->owning_table;
			inter_symbol *alias_to = InterValuePairs::symbol_from_data_pair(val, scope);
			return InterSymbol::evaluate_to_int(alias_to);
		}
	}
	return -1;
}

int Inter::Constant::set_int(inter_symbol *S, int N) {
	inter_tree_node *P = InterSymbol::definition(S);
	if ((P) &&
		(P->W.instruction[ID_IFLD] == CONSTANT_IST) &&
		(P->W.instruction[FORMAT_CONST_IFLD] == CONSTANT_DIRECT)) {
		inter_pair val = InterValuePairs::get(P, DATA_CONST_IFLD);
		if (InterValuePairs::is_number(val)) {
			InterValuePairs::set(P, DATA_CONST_IFLD, InterValuePairs::number((inter_ti) N));
			return TRUE;
		}
		if (InterValuePairs::holds_symbol(val)) {
			inter_symbols_table *scope = S->owning_table;
			inter_symbol *alias_to = InterValuePairs::symbol_from_data_pair(val, scope);
			InterSymbol::set_int(alias_to, N);
			return TRUE;
		}
	}
	return FALSE;
}
