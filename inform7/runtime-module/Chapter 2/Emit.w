[Emit::] Emit.

"Emitting" is the process of generating Inter bytecode, and this section provides
a comprehensive API for the runtime and imperative modules to do that.

@h The emission tree.
The //bytecode// module can maintain multiple independent trees of Inter code
in memory, so that most calls to //bytecode// or //building// take an |inter_tree|
pointer as their first function argument. But //runtime// and //imperative// work
on just one single tree.

Calling |LargeScale::begin_new_tree| makes a minimum of package types,
creates the |main| package, and so on, but leaves the tree basically still empty.

=
inter_tree *main_emission_tree = NULL;

inter_tree *Emit::create_emission_tree(void) {
	main_emission_tree = InterTree::new();
	LargeScale::begin_new_tree(main_emission_tree);
	return main_emission_tree;
}
inter_tree *Emit::tree(void) {
	return main_emission_tree;
}

inter_ti Emit::symbol_id(inter_symbol *S) {
	return InterSymbolsTable::id_from_symbol_at_bookmark(Emit::at(), S);
}

inter_warehouse *Emit::warehouse(void) {
	return InterTree::warehouse(Emit::tree());
}

inter_bookmark *Emit::at(void) {
	return Packaging::at(Emit::tree());
}

inter_ti Emit::baseline(void) {
	return Produce::baseline(Emit::at());
}

inter_package *Emit::package(void) {
	return InterBookmark::package(Emit::at());
}

package_request *Emit::current_enclosure(void) {
	return Packaging::enclosure(Emit::tree());
}

packaging_state Emit::new_packaging_state(void) {
	return Packaging::stateless();
}

@h Data as pairs of Inter bytes.
A single data value is stored in Inter bytecode as two consecutive words:
see //bytecode// for more on this. This means we sometimes deal with a doublet
of |inter_ti| variables:

=
void Emit::holster_iname(value_holster *VH, inter_name *iname) {
	if (Holsters::value_pair_allowed(VH)) {
		if (iname == NULL) internal_error("no iname to holster");
		inter_ti v1 = 0, v2 = 0;
		Emit::to_value_pair(&v1, &v2, iname);
		Holsters::holster_pair(VH, v1, v2);
	}
}

@ A subtlety here is that the encoding of a symbol into a doublet depends on
what package it belongs to, the "context" referred to below:

=
void Emit::symbol_to_value_pair(inter_ti *v1, inter_ti *v2, inter_symbol *S) {
	Emit::stvp_inner(S, v1, v2, InterBookmark::package(Emit::at()));
}

void Emit::to_value_pair(inter_ti *v1, inter_ti *v2, inter_name *iname) {
	Emit::stvp_inner(InterNames::to_symbol(iname), v1, v2, InterBookmark::package(Emit::at()));
}

void Emit::to_value_pair_in_context(inter_name *context, inter_ti *v1, inter_ti *v2,
	inter_name *iname) {
	inter_package *pack = Packaging::incarnate(InterNames::location(context));
	inter_symbol *S = InterNames::to_symbol(iname);
	Emit::stvp_inner(S, v1, v2, pack);
}

void Emit::stvp_inner(inter_symbol *S, inter_ti *v1, inter_ti *v2,
	inter_package *pack) {
	if (S) {
		InterValuePairs::from_symbol(InterPackage::tree(pack), pack, S, v1, v2);
		return;
	}
	*v1 = LITERAL_IVAL; *v2 = 0;
}

@h Kinds.
Inter has a very simple, and non-binding, system of "typenames" -- a much simpler
system than Inform's hierarchy of kinds. Here we create a typename corresponding
to each kind whose data we will need to use in Inter. |super| is the superkind,
if any; |constructor| is one of the codes defined in //bytecode: Inter Data Types//;
the other three arguments are for kind constructors.

@d MAX_KIND_ARITY 128

=
void Emit::kind(inter_name *iname, inter_name *super,
	inter_ti constructor, int arity, kind **operand_kinds) {
	packaging_state save = Packaging::enter_home_of(iname);
	inter_symbol *S = InterNames::to_symbol(iname);
	inter_ti SID = 0;
	if (S) SID = Emit::symbol_id(S);
	inter_symbol *SS = (super)?InterNames::to_symbol(super):NULL;
	inter_ti SUP = 0;
	if (SS) SUP = Emit::symbol_id(SS);
	inter_ti operands[MAX_KIND_ARITY];
	if (arity > MAX_KIND_ARITY) internal_error("kind arity too high");
	for (int i=0; i<arity; i++) {
		if ((operand_kinds[i] == K_nil) || (operand_kinds[i] == K_void)) operands[i] = 0;
		else operands[i] = Produce::kind_to_TID(Emit::at(), operand_kinds[i]);
	}
	Emit::kind_inner(SID, SUP, constructor, arity, operands);
	InterNames::to_symbol(iname);
	Packaging::exit(Emit::tree(), save);
}

@ The above both use:

=
void Emit::kind_inner(inter_ti SID, inter_ti SUP,
	inter_ti constructor, int arity, inter_ti *operands) {
	Produce::guard(Inter::Typename::new(Emit::at(), SID, constructor, SUP, arity,
		operands, Emit::baseline(), NULL));
}

@ Default values for kinds are emitted thus. This is inefficient and maybe ought
to be replaced by a hash, but the list is short and the function is called
so little that it probably makes little difference.

=
linked_list *default_values_written = NULL;

void Emit::ensure_defaultvalue(kind *K) {
	if (K == K_value) return;
	if (default_values_written == NULL) default_values_written = NEW_LINKED_LIST(kind);
	kind *L;
	LOOP_OVER_LINKED_LIST(L, kind, default_values_written)
		if (Kinds::eq(K, L))
			return;
	ADD_TO_LINKED_LIST(K, kind, default_values_written);
	inter_ti v1 = 0, v2 = 0;
	DefaultValues::to_value_pair(&v1, &v2, K);
	if (v1 != 0) {
		packaging_state save = Packaging::enter(RTKindConstructors::kind_package(K));
		Produce::guard(Inter::DefaultValue::new(Emit::at(),
			Produce::kind_to_TID(Emit::at(), K), v1, v2,
			Emit::baseline(), NULL));
		Packaging::exit(Emit::tree(), save);
	}
}

@h Pragmas.
The Inter language allows pragmas, or code-generation hints, to be passed
through. These are specific to the target of compilation, and can be ignored
by all other targets. Here we generate only I6-target pragmas, which are commands
in I6's "Inform Control Language".

=
void Emit::pragma(text_stream *text) {
	inter_tree *I = Emit::tree();
	LargeScale::emit_pragma(I, I"Inform6", text);
}

@h Constants.
These functions make it easy to define a named value in Inter. If the value is
an unsigned numeric constant, use one of these two functions -- the first if
it represents an actual number at run-time, the second if not:

=
inter_name *Emit::numeric_constant(inter_name *con_iname, inter_ti val) {
	return Emit::numeric_constant_inner(con_iname, val, INT32_ITCONC, INVALID_IANN);
}

inter_name *Emit::named_numeric_constant_hex(inter_name *con_iname, inter_ti val) {
	return Emit::numeric_constant_inner(con_iname, val, INT32_ITCONC, HEX_IANN);
}

inter_name *Emit::named_unchecked_constant_hex(inter_name *con_iname, inter_ti val) {
	return Emit::numeric_constant_inner(con_iname, val, UNCHECKED_ITCONC, HEX_IANN);
}

inter_name *Emit::named_numeric_constant_signed(inter_name *con_iname, int val) {
	return Emit::numeric_constant_inner(con_iname, (inter_ti) val, INT32_ITCONC, SIGNED_IANN);
}

inter_name *Emit::unchecked_numeric_constant(inter_name *con_iname, inter_ti val) {
	return Emit::numeric_constant_inner(con_iname, val, UNCHECKED_ITCONC, INVALID_IANN);
}

inter_name *Emit::numeric_constant_inner(inter_name *con_iname, inter_ti val,
	inter_ti constructor_code, inter_ti annotation) {
	packaging_state save = Packaging::enter_home_of(con_iname);
	inter_symbol *con_s = InterNames::to_symbol(con_iname);
	if (annotation != INVALID_IANN) SymbolAnnotation::set_b(con_s, annotation, 0);
	inter_ti TID = InterTypes::to_TID(InterBookmark::scope(Emit::at()),
		InterTypes::from_constructor_code(constructor_code));
	Produce::guard(Inter::Constant::new_numerical(Emit::at(), Emit::symbol_id(con_s),
		TID, LITERAL_IVAL, val, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
	return con_iname;
}

@ Text:

=
void Emit::text_constant(inter_name *con_iname, text_stream *contents) {
	packaging_state save = Packaging::enter_home_of(con_iname);
	inter_ti ID = InterWarehouse::create_text(Emit::warehouse(),
		Emit::package());
	Str::copy(InterWarehouse::get_text(Emit::warehouse(), ID), contents);
	inter_symbol *con_s = InterNames::to_symbol(con_iname);
	inter_ti TID = InterTypes::to_TID(InterBookmark::scope(Emit::at()),
		InterTypes::from_constructor_code(TEXT_ITCONC));
	Produce::guard(Inter::Constant::new_textual(Emit::at(), Emit::symbol_id(con_s),
		TID, ID, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
}

@ And equating one constant to another named constant:

=
inter_name *Emit::iname_constant(inter_name *con_iname, kind *K, inter_name *val_iname) {
	packaging_state save = Packaging::enter_home_of(con_iname);
	inter_symbol *con_s = InterNames::to_symbol(con_iname);
	inter_symbol *val_s = (val_iname)?InterNames::to_symbol(val_iname):NULL;
	if (val_s == NULL) {
		if (Kinds::Behaviour::is_object(K))
			val_s = InterNames::to_symbol(Hierarchy::find(NOTHING_HL));
		else
			internal_error("can't handle a null alias");
	}
	inter_ti v1 = 0, v2 = 0;
	Emit::symbol_to_value_pair(&v1, &v2, val_s);
	Produce::guard(Inter::Constant::new_numerical(Emit::at(), Emit::symbol_id(con_s),
		Produce::kind_to_TID(Emit::at(), K), v1, v2, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
	return con_iname;
}

@ These two variants are needed only for the oddball way //Bibliographic Data//
is compiled.

=
void Emit::text_constant_from_wide_string(inter_name *con_iname, wchar_t *str) {
	inter_ti v1 = 0, v2 = 0;
	inter_name *iname = TextLiterals::to_value(Feeds::feed_C_string(str));
	Emit::to_value_pair_in_context(con_iname, &v1, &v2, iname);
	Emit::named_generic_constant(con_iname, v1, v2);
}

void Emit::serial_number(inter_name *con_iname, text_stream *serial) {
	packaging_state save = Packaging::enter_home_of(con_iname);
	inter_ti v1 = 0, v2 = 0;
	ProducePairs::from_text(Emit::tree(), &v1, &v2, serial);
	Emit::named_generic_constant(con_iname, v1, v2);
	Packaging::exit(Emit::tree(), save);
}

@ Similarly, there are just a few occasions when we need to extract the value
of a "variable" and define it as a constant:

=
void Emit::initial_value_as_constant(inter_name *con_iname, nonlocal_variable *var) {
	inter_ti v1 = 0, v2 = 0;
	RTVariables::initial_value_as_pair(con_iname, &v1, &v2, var);
	Emit::named_generic_constant(con_iname, v1, v2);
}

void Emit::initial_value_as_raw_text(inter_name *con_iname, nonlocal_variable *var) {
	wording W = NonlocalVariables::initial_value_as_plain_text(var);
	TEMPORARY_TEXT(CONTENT)
	BibliographicData::compile_bibliographic_text(CONTENT,
		Lexer::word_text(Wordings::first_wn(W)), XML_BIBTEXT_MODE);
	Emit::text_constant(con_iname, CONTENT);
	DISCARD_TEXT(CONTENT)
}

@ The above make use of this:

=
void Emit::named_generic_constant(inter_name *con_iname, inter_ti v1, inter_ti v2) {
	packaging_state save = Packaging::enter_home_of(con_iname);
	inter_symbol *con_s = InterNames::to_symbol(con_iname);
	inter_ti KID = InterTypes::to_TID(InterBookmark::scope(Emit::at()), InterTypes::untyped());
	Produce::guard(Inter::Constant::new_numerical(Emit::at(), Emit::symbol_id(con_s),
		KID, v1, v2, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
}

@h Instances.

=
void Emit::instance(inter_name *inst_iname, kind *K, int v) {
	packaging_state save = Packaging::enter_home_of(inst_iname);
	inter_symbol *inst_s = InterNames::to_symbol(inst_iname);
	inter_ti v1 = LITERAL_IVAL, v2 = (inter_ti) v;
	if (v == 0) { v1 = UNDEF_IVAL; v2 = 0; }
	Produce::guard(Inter::Instance::new(Emit::at(), Emit::symbol_id(inst_s),
		Produce::kind_to_TID(Emit::at(), K), v1, v2, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
}

@h Variables.

=
inter_symbol *Emit::variable(inter_name *var_iname, kind *K, inter_ti v1, inter_ti v2) {
	packaging_state save = Packaging::enter_home_of(var_iname);
	inter_symbol *var_s = InterNames::to_symbol(var_iname);
	inter_type type = InterTypes::untyped();
	if ((K) && (K != K_value))
		type = InterTypes::from_type_name(Produce::kind_to_symbol(K));
	Produce::guard(Inter::Variable::new(Emit::at(),
		Emit::symbol_id(var_s), type, v1, v2, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
	return var_s;
}

@h Properties and permissions.

=
void Emit::property(inter_name *prop_iname, kind *K) {
	packaging_state save = Packaging::enter_home_of(prop_iname);
	inter_symbol *prop_s = InterNames::to_symbol(prop_iname);
	inter_type type = InterTypes::untyped();
	if ((K) && (K != K_value))
		type = InterTypes::from_type_name(Produce::kind_to_symbol(K));
	Produce::guard(Inter::Property::new(Emit::at(),
		Emit::symbol_id(prop_s), type, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
}

int ppi7_counter = 0;
void Emit::permission(property *prn, inter_symbol *owner_name,
	inter_name *storage_iname) {
	inter_name *prop_iname = RTProperties::iname(prn);
	inter_symbol *store_s = (storage_iname)?InterNames::to_symbol(storage_iname):NULL;
	inter_symbol *prop_s = InterNames::to_symbol(prop_iname);
	inter_error_message *E = NULL;
	TEMPORARY_TEXT(ident)
	WRITE_TO(ident, "pp_i7_%d", ppi7_counter++);
	inter_symbol *pp_s =
		TextualInter::new_symbol(NULL, InterBookmark::scope(Emit::at()), ident, &E);
	DISCARD_TEXT(ident)
	Produce::guard(E);
	Produce::guard(Inter::Permission::new(Emit::at(),
		Emit::symbol_id(prop_s), Emit::symbol_id(owner_name), Emit::symbol_id(pp_s),
		(store_s)?(Emit::symbol_id(store_s)):0, Emit::baseline(), NULL));
}

@h Property values.

=
void Emit::propertyvalue(property *P, inter_name *owner, inter_ti v1, inter_ti v2) {
	inter_symbol *prop_s = InterNames::to_symbol(RTProperties::iname(P));
	inter_symbol *owner_s = InterNames::to_symbol(owner);
	Produce::guard(Inter::PropertyValue::new(Emit::at(),
		Emit::symbol_id(prop_s),
		Emit::symbol_id(owner_s), v1, v2, Emit::baseline(), NULL));
}

@h Private, keep out.
The following should be called only by //imperative: Functions//, which provides
the real API for starting and ending functions.

=
void Emit::function(inter_name *fn_iname, kind *K, inter_package *block) {
	if (Emit::at() == NULL) internal_error("no inter repository");
	inter_symbol *fn_s = InterNames::to_symbol(fn_iname);
	Produce::guard(Inter::Constant::new_function(Emit::at(),
		Emit::symbol_id(fn_s), Produce::kind_to_TID(Emit::at(), K), block,
		Emit::baseline(), NULL));
}

@h Interventions.
These should be used as little as possible, and perhaps it may one day be possible
to abolish them altogether. They insert direct kit material (i.e. paraphrased Inter
code written out as plain text in Inform 6 notation) into bytecode; this is then
assimilating during linking.

=
void Emit::intervention(int stage, text_stream *segment, text_stream *part,
	text_stream *i6, text_stream *seg) {
	inter_warehouse *warehouse = Emit::warehouse();
	inter_ti ID1 = InterWarehouse::create_text(warehouse, Emit::package());
	Str::copy(InterWarehouse::get_text(Emit::warehouse(), ID1), segment);

	inter_ti ID2 = InterWarehouse::create_text(warehouse, Emit::package());
	Str::copy(InterWarehouse::get_text(Emit::warehouse(), ID2), part);

	inter_ti ID3 = InterWarehouse::create_text(warehouse, Emit::package());
	Str::copy(InterWarehouse::get_text(Emit::warehouse(), ID3), i6);

	inter_ti ID4 = InterWarehouse::create_text(warehouse, Emit::package());
	Str::copy(InterWarehouse::get_text(Emit::warehouse(), ID4), seg);

	Produce::guard(Inter::Link::new(Emit::at(), (inter_ti) stage,
		ID1, ID2, ID3, ID4, Emit::baseline(), NULL));
}

@ And this is a similarly inelegant construction:

=
void Emit::append(inter_name *iname, text_stream *text) {
	LOG("Append '%S'\n", text);
	packaging_state save = Packaging::enter_home_of(iname);
	inter_symbol *symbol = InterNames::to_symbol(iname);
	inter_ti ID = InterWarehouse::create_text(Emit::warehouse(), Emit::package());
	Str::copy(InterWarehouse::get_text(Emit::warehouse(), ID), text);
	Produce::guard(Inter::Append::new(Emit::at(), symbol, ID, Emit::baseline(), NULL));
	Packaging::exit(Emit::tree(), save);
}
