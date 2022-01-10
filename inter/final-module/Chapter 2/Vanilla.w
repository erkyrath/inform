[Vanilla::] Vanilla.

The plain-vanilla code generation strategy, provided for the use of generators
to imperative languages such as Inform 6 or C.

@ The rest of this chapter is a plain-vanilla algorithm for turning Inter trees
to imperative code, making method calls to the generator to handle each individual
step as needed. I think this works quite elegantly, but then every beetle is a
gazelle in the eyes of its mother.

The following function does everything except that the generator has already been
sent the |BEGIN_GENERATION_MTID| method, and that the generator will subsequently
be sent |END_GENERATION_MTID|: see //Generators::go//.

=
void Vanilla::go(code_generation *gen) {
	@<Traverse for pragmas@>;
	Generators::declare_variables(gen, gen->global_variables);
	VanillaObjects::declare_properties(gen);
	VanillaFunctions::predeclare_functions(gen);
	@<General traverse@>;
	VanillaConstants::declare_text_literals(gen);
	VanillaObjects::declare_kinds_and_instances(gen);
}

@ Since pragma settings may affect what the generator does (that is the point
of them, after all), we want to send those to the generator first of all. It
can act on them or ignore them as it pleases.

@<Traverse for pragmas@> =
	InterTree::traverse_root_only(gen->from, Vanilla::pragma, gen, PRAGMA_IST);

@ =
void Vanilla::pragma(inter_tree *I, inter_tree_node *P, void *state) {
	code_generation *gen = (code_generation *) state;
	inter_symbol *target_s = InterSymbolsTables::symbol_from_frame_data(P, TARGET_PRAGMA_IFLD);
	if (target_s == NULL) internal_error("bad pragma");
	inter_ti ID = P->W.data[TEXT_PRAGMA_IFLD];
	text_stream *S = Inode::ID_to_text(P, ID);
	Generators::offer_pragma(gen, P, target_s->symbol_name, S);
}

@<General traverse@> =
	gen->void_level = -1;
	InterTree::traverse(gen->from, Vanilla::iterate, gen, NULL, -PACKAGE_IST);

@ This looks for the top level of packages which are not the code-body of
functions, and calls //Vanilla::node// to recurse downwards through them.

=
void Vanilla::iterate(inter_tree *I, inter_tree_node *P, void *state) {
	code_generation *gen = (code_generation *) state;
	inter_package *outer = Inter::Packages::container(P);
	if ((outer == NULL) || (Inter::Packages::is_codelike(outer) == FALSE)) {
		switch (P->W.data[ID_IFLD]) {
			case CONSTANT_IST:
			case VARIABLE_IST:
			case SPLAT_IST:
			case INSTANCE_IST:
			case PROPERTYVALUE_IST:
				Vanilla::node(gen, P);
				break;
		}
	}
}

@ The function //Vanilla::node// is a sort of handle-any-node function, and is
the main way we iterate through the Inter tree.

Note that the general-traverse iteration above calls into this function, but
that the function then recurses down through nodes. As a result, it sees pretty
well the entire tree by the end.

The current node is always called |P|, for reasons now forgotten.

It is so often used recursively that the following abbreviation macros are helpful:

@d VNODE_1C    Vanilla::node(gen, InterTree::first_child(P))
@d VNODE_2C    Vanilla::node(gen, InterTree::second_child(P))
@d VNODE_3C    Vanilla::node(gen, InterTree::third_child(P))
@d VNODE_4C    Vanilla::node(gen, InterTree::fourth_child(P))
@d VNODE_5C    Vanilla::node(gen, InterTree::fifth_child(P))
@d VNODE_6C    Vanilla::node(gen, InterTree::sixth_child(P))
@d VNODE_ALLC  LOOP_THROUGH_INTER_CHILDREN(C, P) Vanilla::node(gen, C)

=
void Vanilla::node(code_generation *gen, inter_tree_node *P) {
	switch (P->W.data[ID_IFLD]) {
		case CONSTANT_IST:      VanillaConstants::constant(gen, P); break;

		case LABEL_IST:         VanillaCode::label(gen, P); break;
		case CODE_IST:          VanillaCode::code(gen, P); break;
		case EVALUATION_IST:    VanillaCode::evaluation(gen, P); break;
		case REFERENCE_IST:     VanillaCode::reference(gen, P); break;
		case INV_IST:           VanillaCode::inv(gen, P); break;
		case CAST_IST:          VanillaCode::cast(gen, P); break;
		case VAL_IST:           VanillaCode::val_or_ref(gen, P, FALSE); break;
		case REF_IST:           VanillaCode::val_or_ref(gen, P, TRUE); break;
		case ASSEMBLY_IST:      VanillaCode::assembly(gen, P); break;
		case LAB_IST:           VanillaCode::lab(gen, P); break;

		case SPLAT_IST:         Vanilla::splat(gen, P); break;
		case PACKAGE_IST:       VNODE_ALLC; break;

		case INSTANCE_IST:      break;
		case VARIABLE_IST:      break;
		case PROPERTYVALUE_IST: break;
		case SYMBOL_IST:        break;
		case LOCAL_IST:         break;
		case NOP_IST:           break;
		case COMMENT_IST:       break;

		default:
			Inter::Defn::write_construct_text(DL, P);
			internal_error("unexpected node type in Inter tree");
	}
}

@ |splat| nodes are the joker in the pack. They copy material verbatim to the
output, regardless of the language being generated. (In practice, of course, this
means that the content of a |splat| must carefully have been pre-generated in
the right format.) Inform uses such nodes as little as it possibly can.

A wrinkle, though, is that the special |URL_SYMBOL_CHAR| is used to mark out
a URL for a symbol in the Inter tree: this is replaced with its properly
generated name. So a splat is not quite generator-independent after all.

@d URL_SYMBOL_CHAR 0x00A7

=
void Vanilla::splat(code_generation *gen, inter_tree_node *P) {
	text_stream *OUT = CodeGen::current(gen);
	inter_tree *I = gen->from;
	text_stream *S =
		Inter::Warehouse::get_text(InterTree::warehouse(I), P->W.data[MATTER_SPLAT_IFLD]);
	Vanilla::splat_matter(OUT, I, S);
}

void Vanilla::splat_matter(OUTPUT_STREAM, inter_tree *I, text_stream *S) {
	int L = Str::len(S);
	for (int i=0; i<L; i++) {
		wchar_t c = Str::get_at(S, i);
		if (c == URL_SYMBOL_CHAR) {
			TEMPORARY_TEXT(T)
			for (i++; i<L; i++) {
				wchar_t c = Str::get_at(S, i);
				if (c == URL_SYMBOL_CHAR) break;
				PUT_TO(T, c);
			}
			inter_symbol *symb = InterSymbolsTables::url_name_to_symbol(I, NULL, T);
			WRITE("%S", Inter::Symbols::name(symb));
			DISCARD_TEXT(T)
		} else PUT(c);
	}
}
