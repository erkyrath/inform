[VanillaConstants::] Vanilla Constants.

How the vanilla code generation strategy handles constants, including literal
texts, lists, and arrays.

@ During the main //Vanilla// traverse, this is called on each constant definition
in the tree:

=
void VanillaConstants::constant(code_generation *gen, inter_tree_node *P) {
	inter_symbol *con_name =
		InterSymbolsTables::symbol_from_frame_data(P, DEFN_CONST_IFLD);
	if (con_name == NULL) internal_error("no constant");
	if (con_name->metadata_key == FALSE) {
		if (Inter::Symbols::read_annotation(con_name, ACTION_IANN) == 1)  {
			@<Declare this constant as an action name@>;
		} else if (Inter::Symbols::read_annotation(con_name, FAKE_ACTION_IANN) == 1) {
			@<Declare this constant as a fake action name@>;
		} else if (Inter::Symbols::read_annotation(con_name, VENEER_IANN) > 0) {
			@<Ignore this constant as part of the veneer@>;
		} else if (Inter::Symbols::read_annotation(con_name, OBJECT_IANN) > 0) {
			@<Declare this constant as a pseudo-object@>;
		} else if (Inter::Constant::is_routine(con_name)) {
			@<Declare this constant as a function@>;
		} else if (Str::eq(con_name->symbol_name, I"UUID_ARRAY")) {
			@<Declare this constant as the special UUID string array@>;
		} else switch (P->W.data[FORMAT_CONST_IFLD]) {
			case CONSTANT_INDIRECT_TEXT: @<Declare this as a textual constant@>; break;
			case CONSTANT_INDIRECT_LIST: @<Declare this as a list constant@>; break;
			case CONSTANT_SUM_LIST:
			case CONSTANT_PRODUCT_LIST:
			case CONSTANT_DIFFERENCE_LIST:
			case CONSTANT_QUOTIENT_LIST: @<Declare this as a computed constant@>; break;
			case CONSTANT_DIRECT: @<Declare this as an explicit constant@>; break;
			default: internal_error("ungenerated constant format");
		}
	}
}

@<Declare this constant as an action name@> =
	text_stream *fa = Str::duplicate(con_name->symbol_name);
	Str::delete_first_character(fa);
	Str::delete_first_character(fa);
	Generators::new_action(gen, fa, TRUE);

@<Declare this constant as a fake action name@> =
	text_stream *fa = Str::duplicate(con_name->symbol_name);
	Str::delete_first_character(fa);
	Str::delete_first_character(fa);
	Generators::new_action(gen, fa, FALSE);

@<Ignore this constant as part of the veneer@> =
	;

@<Declare this constant as a pseudo-object@> =
	Generators::pseudo_object(gen, Inter::Symbols::name(con_name));

@<Declare this constant as a function@> =
	inter_package *code_block = Inter::Constant::code_block(con_name);
	inter_tree_node *D = Inter::Packages::definition(code_block);
	Generators::declare_function(gen, con_name, D);

@<Declare this constant as the special UUID string array@> =
	inter_ti ID = P->W.data[DATA_CONST_IFLD];
	text_stream *S = Inode::ID_to_text(P, ID);
	segmentation_pos saved;
	TEMPORARY_TEXT(content)
	TEMPORARY_TEXT(length)
	WRITE_TO(content, "UUID://");
	for (int i=0, L=Str::len(S); i<L; i++)
		WRITE_TO(content, "%c", Characters::toupper(Str::get_at(S, i)));
	WRITE_TO(content, "//");
	WRITE_TO(length, "%d", (int) Str::len(content));

	Generators::begin_array(gen, I"UUID_ARRAY", NULL, NULL, BYTE_ARRAY_FORMAT, &saved);
	Generators::array_entry(gen, length, BYTE_ARRAY_FORMAT);
	LOOP_THROUGH_TEXT(pos, content) {
		TEMPORARY_TEXT(ch)
		WRITE_TO(ch, "'%c'", Str::get(pos));
		Generators::array_entry(gen, ch, BYTE_ARRAY_FORMAT);
		DISCARD_TEXT(ch)
	}
	Generators::end_array(gen, BYTE_ARRAY_FORMAT, &saved);
	DISCARD_TEXT(length)
	DISCARD_TEXT(content)

@<Declare this as a textual constant@> =
	inter_ti ID = P->W.data[DATA_CONST_IFLD];
	text_stream *S = Inode::ID_to_text(P, ID);
	VanillaConstants::defer_declaring_literal_text(gen, S, con_name);

@ Inter supports four sorts of arrays, with behaviour as laid out in this 2x2 grid:
= (text)
			 | entries count 0, 1, 2,...	 | entry 0 is N, then entries count 1, 2, ..., N
-------------+-------------------------------+-----------------------------------------------
byte entries | BYTE_ARRAY_FORMAT             | BUFFER_ARRAY_FORMAT
-------------+-------------------------------+-----------------------------------------------
word entries | WORD_ARRAY_FORMAT             | TABLE_ARRAY_FORMAT
-------------+-------------------------------+-----------------------------------------------
=
In most cases, the entries in the list are then given in value pairs from |DATA_CONST_IFLD|
to the end of the frame. However:
(a) |DIVIDER_IVAL| entries are not real entries, but just places where comments
or line breaks could be placed to make the code prettier;
(b) if an array assimilated from a kit has exactly one purported entry, then in
fact this should be interpreted as being that many blank entries. This number
must however be carefully evaluated, as it may be another constant name rather
than a literal, or may even be computed. 

@<Declare this as a list constant@> =
	int format = WORD_ARRAY_FORMAT;
	if (Inter::Symbols::read_annotation(con_name, BYTEARRAY_IANN) == 1) format = BYTE_ARRAY_FORMAT;
	if (Inter::Symbols::read_annotation(con_name, TABLEARRAY_IANN) == 1) format = TABLE_ARRAY_FORMAT;
	if (Inter::Symbols::read_annotation(con_name, BUFFERARRAY_IANN) == 1) format = BUFFER_ARRAY_FORMAT;

	int entry_count = 0;
	for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2)
		if (P->W.data[i] != DIVIDER_IVAL)
			entry_count++;
	int give_count = FALSE;
	if ((entry_count == 1) &&
		(Inter::Symbols::read_annotation(con_name, ASSIMILATED_IANN) >= 0)) {
		inter_ti val1 = P->W.data[DATA_CONST_IFLD], val2 = P->W.data[DATA_CONST_IFLD+1];
		entry_count = (int) Inter::Constant::evaluate(Inter::Packages::scope_of(P), val1, val2);
		give_count = TRUE;
	}

	segmentation_pos saved;
	if (Generators::begin_array(gen, Inter::Symbols::name(con_name), con_name, P, format, &saved)) {
		if (give_count) {
			Generators::array_entries(gen, entry_count, format);
		} else {
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				if (P->W.data[i] != DIVIDER_IVAL) {
					TEMPORARY_TEXT(entry)
					CodeGen::select_temporary(gen, entry);
					CodeGen::pair(gen, P, P->W.data[i], P->W.data[i+1]);
					CodeGen::deselect_temporary(gen);
					Generators::array_entry(gen, entry, format);
					DISCARD_TEXT(entry)
				}
			}
		}
		Generators::end_array(gen, format, &saved);
	}

@<Declare this as a computed constant@> =
	Generators::declare_constant(gen, Inter::Symbols::name(con_name), con_name,
		COMPUTED_GDCFORM, P, NULL);

@<Declare this as an explicit constant@> =
	Generators::declare_constant(gen, Inter::Symbols::name(con_name), con_name,
		DATA_GDCFORM, P, NULL);

@ When called by //Generators::declare_constant//, generators may if they choose
make use of the following convenient function for generating the value to which a
constant name is given.

Note that this assumes that the usual arithmetic operators and brackets can be
used in the syntax for literal quantities: e.g., it may produce |(A + (3 * B))|
for constants |A|, |B|. If the generator is for a language which doesn't allow
that, it will have to make other arrangements.

=
void VanillaConstants::definition_value(code_generation *gen, int form, inter_tree_node *P,
	inter_symbol *con_name, text_stream *val) {
	text_stream *OUT = CodeGen::current(gen);
	switch (form) {
		case RAW_GDCFORM:
			if (Str::len(val) > 0) {
				WRITE("%S", val);
			} else {
				Generators::compile_literal_number(gen, 1, FALSE);
			}
			break;
		case MANGLED_GDCFORM:
			if (Str::len(val) > 0) {
				Generators::mangle(gen, OUT, val);
			} else {
				Generators::compile_literal_number(gen, 1, FALSE);
			}
			break;
		case DATA_GDCFORM: {
			inter_ti val1 = P->W.data[DATA_CONST_IFLD];
			inter_ti val2 = P->W.data[DATA_CONST_IFLD + 1];
			if ((val1 == LITERAL_IVAL) && (Inter::Symbols::read_annotation(con_name, HEX_IANN)))
				Generators::compile_literal_number(gen, val2, TRUE);
			else
				CodeGen::pair(gen, P, val1, val2);
			break;
		}
		case COMPUTED_GDCFORM: {
			WRITE("(");
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				if (i>DATA_CONST_IFLD) {
					if (P->W.data[FORMAT_CONST_IFLD] == CONSTANT_SUM_LIST) WRITE(" + ");
					if (P->W.data[FORMAT_CONST_IFLD] == CONSTANT_PRODUCT_LIST) WRITE(" * ");
					if (P->W.data[FORMAT_CONST_IFLD] == CONSTANT_DIFFERENCE_LIST) WRITE(" - ");
					if (P->W.data[FORMAT_CONST_IFLD] == CONSTANT_QUOTIENT_LIST) WRITE(" / ");
				}
				int bracket = TRUE;
				if ((P->W.data[i] == LITERAL_IVAL) ||
					(Inter::Symbols::is_stored_in_data(P->W.data[i], P->W.data[i+1]))) bracket = FALSE;
				if (bracket) WRITE("(");
				CodeGen::pair(gen, P, P->W.data[i], P->W.data[i+1]);
				if (bracket) WRITE(")");
			}
			WRITE(")");
			break;
		}
		case LITERAL_TEXT_GDCFORM:
			Generators::compile_literal_text(gen, val, FALSE);
			break;
	}
}

@ During the above process, a constant set equal to a text literal is not
immediately declared: instead, the following mechanism is used to stash it for
later.

=
typedef struct text_literal_holder {
	struct text_stream *literal_content;
	struct inter_symbol *con_name;
	CLASS_DEFINITION
} text_literal_holder;

void VanillaConstants::defer_declaring_literal_text(code_generation *gen, text_stream *S,
	inter_symbol *con_name) {
	text_literal_holder *tlh = CREATE(text_literal_holder);
	tlh->literal_content = S;
	tlh->con_name = con_name;
	ADD_TO_LINKED_LIST(tlh, text_literal_holder, gen->text_literals);
}

@ And now it's later. We go through all of the stashed text literals, and sort
them into alphabetical order; and then declare them. What this whole business
achieves, then, is to declare text constants in alphabetical order rather than
in tree order.

=
void VanillaConstants::declare_text_literals(code_generation *gen) {
	int no_tlh = LinkedLists::len(gen->text_literals);
	if (no_tlh > 0) {
		text_literal_holder **sorted = (text_literal_holder **)
			(Memory::calloc(no_tlh, sizeof(text_literal_holder *), CODE_GENERATION_MREASON));
		int i = 0;
		text_literal_holder *tlh;
		LOOP_OVER_LINKED_LIST(tlh, text_literal_holder, gen->text_literals)
			sorted[i++] = tlh;
		qsort(sorted, (size_t) no_tlh, sizeof(text_literal_holder *),
			VanillaConstants::compare_tlh);
		for (int i=0; i<no_tlh; i++) {
			text_literal_holder *tlh = sorted[i];
			Generators::declare_constant(gen, Inter::Symbols::name(tlh->con_name),
				tlh->con_name, LITERAL_TEXT_GDCFORM, tlh->con_name->definition,
				tlh->literal_content);
		}
	}
}

@ Note that |Str::cmp| is a case-sensitive comparison, so |Zebra| will come
before |armadillo|, for example, |Z| being before |a| in Unicode.

=
int VanillaConstants::compare_tlh(const void *elem1, const void *elem2) {
	const text_literal_holder **e1 = (const text_literal_holder **) elem1;
	const text_literal_holder **e2 = (const text_literal_holder **) elem2;
	if ((*e1 == NULL) || (*e2 == NULL))
		internal_error("Disaster while sorting text literals");
	text_stream *s1 = (*e1)->literal_content;
	text_stream *s2 = (*e2)->literal_content;
	return Str::cmp(s1, s2);
}
