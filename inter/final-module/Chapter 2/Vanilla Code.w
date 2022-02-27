[VanillaCode::] Vanilla Code.

How the vanilla code generation strategy handles the actual code inside functions.

@ The subtrees of Inter inside function bodies are pretty simple. There are
some structural nodes, breaking up code-blocks and the like: and these we
simply recurse down through, except that in the case of |code| we keep track
of the "void level". This is the level in the hierarchy where evaluation is
in a void context. For example,
= (text)
	code
		inv !printnumber
			inv !plus
				val K_number 12
				val K_number 2
		^
		|
		void level
=
here the invocation of |!printnumber| is in a void context (i.e., any value
produced is discarded), whereas the invocation of |!plus| is not.

=
void VanillaCode::code(code_generation *gen, inter_tree_node *P) {
	int old_level = gen->void_level;
	gen->void_level = Inode::get_level(P) + 1;
	VNODE_ALLC;
	gen->void_level = old_level;
}

void VanillaCode::evaluation(code_generation *gen, inter_tree_node *P) { VNODE_ALLC; }
void VanillaCode::reference(code_generation *gen, inter_tree_node *P)  { VNODE_ALLC; }
void VanillaCode::cast(code_generation *gen, inter_tree_node *P)       { VNODE_ALLC; }

@ As with assembly language, Inter can contain positional markers called labels.
These we offer to the generator to deal with as it likes:

=
void VanillaCode::label(code_generation *gen, inter_tree_node *P) {
	inter_package *pack = InterPackage::container(P);
	inter_symbol *lab_name =
		InterSymbolsTable::symbol_from_ID_in_package(pack, P->W.instruction[DEFN_LABEL_IFLD]);
	Generators::place_label(gen, InterSymbol::identifier(lab_name));
}

@ There are three ways to perform an invocation. One of the three, assembly
language, can only in fact occur in void context, but we won't assume that here.

@d MAX_OPERANDS_IN_INTER_ASSEMBLY 32

=
void VanillaCode::inv(code_generation *gen, inter_tree_node *P) {
	int void_context = FALSE;
	if (Inode::get_level(P) == gen->void_level) void_context = TRUE;
	switch (P->W.instruction[METHOD_INV_IFLD]) {
		case INVOKED_PRIMITIVE: @<Invoke a primitive@>; break;
		case INVOKED_ROUTINE: @<Invoke a function@>; break;
		case INVOKED_OPCODE: @<Invoke an assembly-language opcode@>; break;
		default: internal_error("unknown invocation method");
	}
}

@<Invoke a primitive@> =
	inter_symbol *primitive_s = Inter::Inv::invokee(P);
	if (primitive_s == NULL) internal_error("no primitive");
	Generators::invoke_primitive(gen, primitive_s, P, void_context);

@<Invoke a function@> =
	inter_symbol *function_s = Inter::Inv::invokee(P);
	if (function_s == NULL) internal_error("no function");
	VanillaFunctions::invoke_function(gen, function_s, P, void_context);

@<Invoke an assembly-language opcode@> =
	inter_ti ID = P->W.instruction[INVOKEE_INV_IFLD];
	text_stream *opcode_name = Inode::ID_to_text(P, ID);
	inter_tree_node *operands[MAX_OPERANDS_IN_INTER_ASSEMBLY], *label = NULL;
	int operand_count = 0;
	int label_sense = NOT_APPLICABLE;
	@<Scan the operands@>;
	Generators::invoke_opcode(gen, opcode_name, operand_count, operands, label,
		label_sense);

@ Unusually, opcode invocations do not work by recursing down through the tree
to pick up the operands implicitly: instead we gather them into a small array.
This is because of the slightly clumsy way in which labels are represented in
Inter assembly, which we want to take care of here, so that generators don't
need to.

@<Scan the operands@> =
	LOOP_THROUGH_INTER_CHILDREN(F, P) {
		if (F->W.instruction[ID_IFLD] == ASSEMBLY_IST) {
			if (Inter::Assembly::which_marker(F) == ASM_NEG_ASMMARKER) {
				label_sense = FALSE;
				continue;
			}
		}
		if (F->W.instruction[ID_IFLD] == LAB_IST) {
			if (label_sense == NOT_APPLICABLE) label_sense = TRUE;
			label = F; continue;
		}
		if (operand_count < MAX_OPERANDS_IN_INTER_ASSEMBLY)
			operands[operand_count++] = F;
	}

@ If they are not further invocations or code blocks, for which see above, the
nodes under an invocation will be |val|, |ref| or |lab|.

A |ref| can be to a variable; a |val| can be to a named constant, a variable
or a literal. The special |self| symbol, which has no definition, counts as
a variable here.

=
void VanillaCode::val_or_ref(code_generation *gen, inter_tree_node *P, int ref) {
	inter_pair val = InterValuePairs::get(P, VAL1_VAL_IFLD);
	if (InterValuePairs::holds_symbol(val)) {
		inter_symbol *named_s = InterValuePairs::symbol_from_data_pair_at_node(val, P);
		if ((Str::eq(InterSymbol::trans(named_s), I"self")) ||
			((named_s->definition) &&
				(named_s->definition->W.instruction[ID_IFLD] == VARIABLE_IST))) {
			Generators::evaluate_variable(gen, named_s, ref);
		} else {
			Generators::compile_literal_symbol(gen, named_s);
		}
	} else if (InterValuePairs::is_undef(val)) {
		internal_error("undef val/ref in Inter tree");
	} else {
		CodeGen::pair(gen, P, val);
	}	
}

@ A |lab| works on a named label, which will be defined somewhere in the same
function body.

=
void VanillaCode::lab(code_generation *gen, inter_tree_node *P) {
	inter_package *pack = InterPackage::container(P);
	inter_symbol *label_s =
		InterSymbolsTable::symbol_from_ID_in_package(pack, P->W.instruction[LABEL_LAB_IFLD]);
	if (label_s == NULL) internal_error("unknown label in lab in Inter tree");
	Generators::evaluate_label(gen, InterSymbol::identifier(label_s));
}

@ An |assembly| specifies one of a fixed number of special assembly-language
punctuation marks:

=
void VanillaCode::assembly(code_generation *gen, inter_tree_node *P) {
	inter_ti which = Inter::Assembly::which_marker(P);
	Generators::assembly_marker(gen, which);
}
