[I6TargetObjects::] Inform 6 Objects.

To declare I6 objects, classes, attributes and properties.

@ =
void I6TargetObjects::create_generator(code_generator *cgt) {
	METHOD_ADD(cgt, DECLARE_PROPERTY_MTID, I6TargetObjects::declare_property);
	METHOD_ADD(cgt, DECLARE_CLASS_MTID, I6TargetObjects::declare_class);
	METHOD_ADD(cgt, END_CLASS_MTID, I6TargetObjects::end_class);
	METHOD_ADD(cgt, DECLARE_VALUE_INSTANCE_MTID, I6TargetObjects::declare_value_instance);
	METHOD_ADD(cgt, DECLARE_INSTANCE_MTID, I6TargetObjects::declare_instance);
	METHOD_ADD(cgt, END_INSTANCE_MTID, I6TargetObjects::end_instance);
	METHOD_ADD(cgt, OPTIMISE_PROPERTY_MTID, I6TargetObjects::optimise_property_value);
	METHOD_ADD(cgt, ASSIGN_PROPERTY_MTID, I6TargetObjects::assign_property);
	METHOD_ADD(cgt, BEGIN_PROPERTIES_FOR_MTID, I6TargetObjects::begin_properties_for);
	METHOD_ADD(cgt, END_PROPERTIES_FOR_MTID, I6TargetObjects::end_properties_for);
	METHOD_ADD(cgt, ASSIGN_PROPERTIES_MTID, I6TargetObjects::assign_properties);
	METHOD_ADD(cgt, PSEUDO_OBJECT_MTID, I6TargetObjects::pseudo_object);
}

@h A disclaimer.
The two virtual machines compiled to by I6 both support "properties" and
"attributes" attached to "objects" of "classes". We will use all of those features, but
not in a way which exactly matches their similarly-named I7 features. So for
clarity we will call them VN-properties, VM-attributes, VM-objects and VM-classes
in this section of code. For example, this I6 code:
= (text as Inform 6)
Object mandrake_root
	class Mandragora
	with potency 10,
	has edible;
=
creates a VM-object |mandrake_root| of VM-class |Mandragora|, which has the
VM-property |potency| set to 10, and the VM-attribute |edible| set.

@h Property declarations.
Here we must declare properties. Some will be stored in VM-properties, others
in VM-attributes. Owing to a quirk of the I6 language, VM-properties do not
need to be declared before use, though VM-attributes do. The decisions we take
are motivated by the following considerations:

(a) The supply of VM-attributes is limited, so we cannot simply store all
either-or properties in VM-attributes: there might be too many.
(b) The supply of declared VM-properties is also limited (though not of
undeclared ones).
(c) But VM-attributes, and declared VM-properties, can be accessed just a
little faster at runtime, and take just a little less storage.

Because of (c) we don't want to do the simplest possible thing -- i.e., to
make everything an undeclared VM-property and be done with it. Instead, we
do use our limited supplies of (a) and (b), prioritising properties which
come from kits because that will include all the most frequently-used ones.

@ Like any generator, we also have to decide what to put into the first two
words in the metadata array for an I7 property. Since we are using a mixed
strategy for how to store properties, this metadata will have to identify
in each case what is being done. Word 0 will be either 1 or 2, meaning "store
in a VM-property" or "store in a VM-attribute", respectively. Word 1 will
then be the choice of VM-property or VM-attribute in question. For example,
hypothetical I7 properties "potency" and "edible" might have metadata arrays
like so:
= (text)
	A_potency --> 1
	              potency
	              0	  (means "not either-or")
	              ... (permissions)
	A_edible  --> 2
	              edible
	              1   (means "either-or")
	              ... (permissions)
=
Note that at runtime VM-property and VM-attribute numbers may overlap -- so
there is no way to tell from word 1 alone whether it is intended to be a
VM-property number or a VM-attribute number. Indeed, |potency| might compile
to the same number as |edible|. So word 0 is certainly necessary.

=
void I6TargetObjects::declare_property(code_generator *cgt, code_generation *gen,
	inter_symbol *prop_name, linked_list *all_forms) {
	text_stream *inner_name = VanillaObjects::inner_property_name(gen, prop_name);

	int originated_in_a_kit = FALSE;
	@<Find whether this property has been assimilated from a kit@>;

	int store_in_VM_attribute = FALSE;
	@<Decide whether to store this in a VM-attribute@>;

	if (store_in_VM_attribute)    @<Declare a VM-attribute to store this in@>
	else if (originated_in_a_kit) @<Declare a VM-property to store this in@>
	else                          @<Store this in an undeclared VM-property@>;

	@<Compile the two opening words of the property metadata@>;
}

@ For why there are multiple declarations of the same property in the Inter
tree, see //Vanilla Objects//. If any one of them came from a kit, we consider
that definition to be the true one.

@<Find whether this property has been assimilated from a kit@> =
	inter_symbol *p;
	LOOP_OVER_LINKED_LIST(p, inter_symbol, all_forms)
		if (Inter::Symbols::read_annotation(p, ASSIMILATED_IANN) >= 0)
			originated_in_a_kit = TRUE;

@<Decide whether to store this in a VM-attribute@> =
	if (Inter::Symbols::read_annotation(prop_name, EITHER_OR_IANN) == 1) {
		store_in_VM_attribute = NOT_APPLICABLE;
		@<Any either/or property which can belong to a value instance is ineligible@>;
		@<An either/or property coming from a kit must be chosen@>;
		@<Otherwise give away attribute slots on a first-come-first-served basis@>;
	}
	if (store_in_VM_attribute == TRUE) {
		inter_symbol *p;
		LOOP_OVER_LINKED_LIST(p, inter_symbol, all_forms)
			Inter::Symbols::set_flag(p, ATTRIBUTE_MARK_BIT);
	} else if (store_in_VM_attribute == FALSE) {
		inter_symbol *p;
		LOOP_OVER_LINKED_LIST(p, inter_symbol, all_forms)
			Inter::Symbols::clear_flag(p, ATTRIBUTE_MARK_BIT);
	} else {
		internal_error("No decision was taken");
	}

@ In the virtual machine, only VM-objects can have VM-attributes, and instances
of non-object kinds are not going to be implemented as VM-objects. So if a
property needs to be given to such a kind, we cannot store it in a VM-attribute.
For example:
= (text as Inform 7)
Colour is a kind of value. The colours are red, green and blue. A colour
can be garish or dowdy.
=
Here "red", "green" and "blue" are not going to be represented by VM-objects
at runtime: they will be the numbers 1, 2, and 3. So the property "garish"
cannot be a VM-attribute. (Numbers can't, of course, have VM-properties
either, but see below for how we get around that.)

@<Any either/or property which can belong to a value instance is ineligible@> =
	inter_symbol *p;
	LOOP_OVER_LINKED_LIST(p, inter_symbol, all_forms)
		if (VanillaObjects::is_property_of_values(gen, p))
			store_in_VM_attribute = FALSE;

@ We give priority to properties declared in kits, since those in WorldModelKit
and CommandParserKit are by far the most frequently used.

@<An either/or property coming from a kit must be chosen@> =
	if (originated_in_a_kit)
		store_in_VM_attribute = TRUE;

@ We have in theory 48 VM-attributes to use up, that being the number
available in versions 5 and higher of the Z-machine VM, but the standard
kits consume so many that only a few slots remain for the user's own
creations. Giving these away to the first-created properties is the
simplest way to allocate them, and in fact that works pretty well, because
the first such either/or properties tend to be created in extensions and
to be frequently used.

@d ATTRIBUTE_SLOTS_TO_GIVE_AWAY 11

@<Otherwise give away attribute slots on a first-come-first-served basis@> =
	if (store_in_VM_attribute == NOT_APPLICABLE) {
		if (I6_GEN_DATA(attribute_slots_used)++ < ATTRIBUTE_SLOTS_TO_GIVE_AWAY)
			store_in_VM_attribute = TRUE;
		else
			store_in_VM_attribute = FALSE;
	}

@ Okay, declaration time. The I6 |Attribute| directive creates a VM-attribute.
We give it the property's "inner name": see //Vanilla Objects// for why.

@<Declare a VM-attribute to store this in@> =
	segmentation_pos saved = CodeGen::select(gen, constants_I7CGS);
	WRITE_TO(CodeGen::current(gen), "Attribute %S;\n", inner_name);
	CodeGen::deselect(gen, saved);

@ And the |Property| directive declares a VM-property.

@<Declare a VM-property to store this in@> =
	segmentation_pos saved = CodeGen::select(gen, predeclarations_I7CGS);
	WRITE_TO(CodeGen::current(gen), "Property %S;\n", inner_name);
	CodeGen::deselect(gen, saved);

@ It may seem that nothing needs to be done in order to declare an undeclared
VM-property: so why is there code here? In fact, old-time Inform 6 coders will
recognise this situation. Suppose we have a property called |example|, and
we have some I6 code making reference to it:
= (text as Inform 6)
[ EnthuseOver p;
	if (p == example) "Hey, the example property! How about that!";
	"Shucks, just another anonymous property for the pile."
];
=
But now suppose that the I6 user has this code available but has, in fact,
never actually given the |example| property to any object. That means it is
never implicitly declared as a VM-property; and so it does not exist as an
identifier name, which leads to the |EnthuseOver| function failing to compile.
We get around this with a trick called "stubbing the property": placing the
following precautionary code at the end of the program --
= (text as Inform 6)
#ifndef example; Constant example = 0; #endif;
=
Now |example| exists. It's not a valid VM-property, so it will never be seen
in the wild. |EnthuseOver| will never really enthuse, but won't throw syntax
errors either.

@<Store this in an undeclared VM-property@> =
	segmentation_pos saved = CodeGen::select(gen, property_stubs_I7CGS);
	WRITE_TO(CodeGen::current(gen), "#ifndef %S; Constant %S = 0; #endif;\n",
		inner_name, inner_name);
	CodeGen::deselect(gen, saved);

@ Finally, the opening words of the metadata array. This is done in a rather
odd-looking way because of yet another oddity in the I6 compiler whereby not all
VM-property names can be used as array entries, whereas they can all be used
as values of defined |Constant|s. (This in particular is true of the special
property |name|.) So we define
= (text as Inform 6)
Constant subterfuge_20 = example;
Array P_edible --> 1 subterfuge_20 ...
=
rather than:
= (text as Inform 6)
Array P_edible --> 1 example ...
=
The intent of these is the same, of course.

@<Compile the two opening words of the property metadata@> =
	I6_GEN_DATA(subterfuge_count)++;
	segmentation_pos saved = CodeGen::select(gen, constants_I7CGS);
	WRITE_TO(CodeGen::current(gen), "Constant subterfuge_%d = %S;\n",
		I6_GEN_DATA(subterfuge_count), inner_name);
	CodeGen::deselect(gen, saved);

	TEMPORARY_TEXT(val)
	WRITE_TO(val, "%d", (store_in_VM_attribute)?2:1);
	Generators::array_entry(gen, val, WORD_ARRAY_FORMAT);
	Str::clear(val);
	WRITE_TO(val, "subterfuge_%d", I6_GEN_DATA(subterfuge_count));
	Generators::array_entry(gen, val, WORD_ARRAY_FORMAT);
	DISCARD_TEXT(val)

@h Kinds, instances and property values.

=
void I6TargetObjects::declare_class(code_generator *cgt, code_generation *gen, text_stream *class_name, text_stream *printed_name, text_stream *super_class,
	segmentation_pos *saved) {
	*saved = CodeGen::select(gen, main_matter_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("Class %S\n", class_name);
	if (Str::len(super_class) > 0) WRITE("  class %S\n", super_class);
}

void I6TargetObjects::end_class(code_generator *cgt, code_generation *gen, text_stream *class_name, segmentation_pos saved) {
	text_stream *OUT = CodeGen::current(gen);
	WRITE(";\n");
	CodeGen::deselect(gen, saved);
}

void I6TargetObjects::declare_value_instance(code_generator *cgt,
	code_generation *gen, text_stream *instance_name, text_stream *printed_name, text_stream *val) {
	Generators::declare_constant(gen, instance_name, NULL, RAW_GDCFORM, NULL, val);
}

@ For the I6 header syntax, see the DM4. Note that the "hardwired" short
name is intentionally made blank: we always use I6's |short_name| property
instead. I7's spatial plugin, if loaded (as it usually is), will have
annotated the Inter symbol for the object with an arrow count, that is,
a measure of its spatial depth. This we translate into I6 arrow notation.
If the spatial plugin wasn't loaded then we have no notion of containment,
all arrow counts are 0, and we define a flat sequence of free-standing objects.

One last oddball thing is that direction objects have to be compiled in I6
as if they were spatially inside a special object called |Compass|. This doesn't
really make much conceptual sense, and I7 dropped the idea -- it has no
"compass".

=
void I6TargetObjects::declare_instance(code_generator *cgt, code_generation *gen, text_stream *class_name, text_stream *instance_name, text_stream *printed_name, int acount, int is_dir,
	segmentation_pos *saved) {
	*saved = CodeGen::select(gen, main_matter_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("%S", class_name);
	for (int i=0; i<acount; i++) WRITE(" ->");
	WRITE(" %S", instance_name);
	if (is_dir) WRITE(" Compass");
}

void I6TargetObjects::end_instance(code_generator *cgt, code_generation *gen, text_stream *class_name, text_stream *instance_name, segmentation_pos saved) {
	text_stream *OUT = CodeGen::current(gen);
	WRITE(";\n");
	CodeGen::deselect(gen, saved);
}

int I6TargetObjects::optimise_property_value(code_generator *cgt, code_generation *gen, inter_symbol *prop_name, inter_tree_node *X) {
	if (Inter::Symbols::is_stored_in_data(X->W.data[DVAL1_PVAL_IFLD], X->W.data[DVAL2_PVAL_IFLD])) {
		inter_symbol *S = InterSymbolsTables::symbol_from_data_pair_and_frame(X->W.data[DVAL1_PVAL_IFLD], X->W.data[DVAL2_PVAL_IFLD], X);
		if ((S) && (Inter::Symbols::read_annotation(S, INLINE_ARRAY_IANN) == 1)) {
			inter_tree_node *P = Inter::Symbols::definition(S);
			text_stream *OUT = CodeGen::current(gen);
			for (int i=DATA_CONST_IFLD; i<P->W.extent; i=i+2) {
				if (i>DATA_CONST_IFLD) WRITE(" ");
				CodeGen::pair(gen, P, P->W.data[i], P->W.data[i+1]);
			}
			return TRUE;
		}
	}
	return FALSE;
}

void I6TargetObjects::assign_property(code_generator *cgt, code_generation *gen, inter_symbol *prop_name, text_stream *val) {
	text_stream *OUT = CodeGen::current(gen);
	text_stream *property_name = VanillaObjects::inner_property_name(gen, prop_name);
	if (Inter::Symbols::get_flag(prop_name, ATTRIBUTE_MARK_BIT)) {
		if (Str::eq(val, I"0")) WRITE("    has ~%S\n", property_name);
		else WRITE("    has %S\n", property_name);
	} else {
		WRITE("    with %S %S\n", property_name, val);
	}
}

segmentation_pos i6_ap_saved;
void I6TargetObjects::begin_properties_for(code_generator *cgt, code_generation *gen, inter_symbol *kind_name) {
	TEMPORARY_TEXT(instance_name)
	WRITE_TO(instance_name, "VPH_%d", VanillaObjects::weak_id(kind_name));
	Generators::declare_instance(gen, I"Object", instance_name, NULL, -1, FALSE, &i6_ap_saved);
	DISCARD_TEXT(instance_name)
	Inter::Symbols::set_flag(kind_name, KIND_WITH_PROPS_MARK_BIT);
}

void I6TargetObjects::assign_properties(code_generator *cgt, code_generation *gen, inter_symbol *kind_name, inter_symbol *prop_name, text_stream *array) {
	I6TargetObjects::assign_property(cgt, gen, prop_name, array);
}

void I6TargetObjects::end_properties_for(code_generator *cgt, code_generation *gen, inter_symbol *kind_name) {
	Generators::end_instance(gen, I"Object", NULL, i6_ap_saved);
}

void I6TargetObjects::pseudo_object(code_generator *cgt, code_generation *gen, text_stream *obj_name) {
	segmentation_pos saved = CodeGen::select(gen, main_matter_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("Object %S \"(%S object)\" has concealed;\n", obj_name, obj_name);
	CodeGen::deselect(gen, saved);
}

@ =
void I6TargetObjects::end_generation(code_generator *cgt, code_generation *gen) {
	if (I6_GEN_DATA(property_offsets_made) > 0) @<Complete the property offset creator@>;
	if (I6_GEN_DATA(DebugAttribute_seen) == FALSE) @<Compile a DebugAttribute function@>;
	if (I6_GEN_DATA(value_ranges_needed)) @<Compile the value_ranges array@>;
	if (I6_GEN_DATA(value_property_holders_needed)) @<Compile the value_property_holders array@>;
	@<Compile some property access code@>;
}

@<Complete the property offset creator@> =
	segmentation_pos saved = CodeGen::select(gen, property_offset_creator_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	OUTDENT;
	WRITE("];\n");
	CodeGen::deselect(gen, saved);

@<Compile a DebugAttribute function@> =
	segmentation_pos saved = CodeGen::select(gen, routines_at_eof_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("[ DebugAttribute a anames str;\n");
	WRITE("    print \"<attribute \", a, \">\";\n");
	WRITE("];\n");
	CodeGen::deselect(gen, saved);

@<Compile the value_ranges array@> =
	segmentation_pos saved = CodeGen::select(gen, predeclarations_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("Array value_ranges --> 0");
	inter_symbol *max_weak_id = InterSymbolsTables::url_name_to_symbol(gen->from, NULL, 
		I"/main/synoptic/kinds/BASE_KIND_HWM");
	if (max_weak_id) {
		int M = Inter::Symbols::evaluate_to_int(max_weak_id);
		for (int w=1; w<M; w++) {
			int written = FALSE;
			inter_symbol *kind_name;
			LOOP_OVER_LINKED_LIST(kind_name, inter_symbol, gen->kinds_in_declaration_order) {
				if (VanillaObjects::weak_id(kind_name) == w) {
					if (Inter::Symbols::get_flag(kind_name, KIND_WITH_PROPS_MARK_BIT)) {
						written = TRUE;
						WRITE(" %d", Inter::Kind::instance_count(kind_name));
					}
				}
			}
			if (written == FALSE) WRITE(" 0");
		}
		WRITE(";\n");
	}
	CodeGen::deselect(gen, saved);

@<Compile the value_property_holders array@> =
	segmentation_pos saved = CodeGen::select(gen, predeclarations_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("Array value_property_holders --> 0");
	inter_symbol *max_weak_id = InterSymbolsTables::url_name_to_symbol(gen->from, NULL, 
		I"/main/synoptic/kinds/BASE_KIND_HWM");
	if (max_weak_id) {
		int M = Inter::Symbols::evaluate_to_int(max_weak_id);
		for (int w=1; w<M; w++) {
			int written = FALSE;
			inter_symbol *kind_name;
			LOOP_OVER_LINKED_LIST(kind_name, inter_symbol, gen->kinds_in_declaration_order) {
				if (VanillaObjects::weak_id(kind_name) == w) {
					if (Inter::Symbols::get_flag(kind_name, KIND_WITH_PROPS_MARK_BIT)) {
						written = TRUE;
						WRITE(" VPH_%d", w);
					}
				}
			}
			if (written == FALSE) WRITE(" 0");
		}
		WRITE(";\n");
	}
	CodeGen::deselect(gen, saved);

@<Compile some property access code@> =
	segmentation_pos saved = CodeGen::select(gen, routines_at_eof_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("[ _final_read_pval o p a t;\n");
	WRITE("    t = p-->0; p = p-->1; ! print \"has \", o, \" \", p, \"^\";\n");
	WRITE("    if (t == 2) { if (o has p) a = 1; return a; }\n");
	WRITE("    if ((o provides p) && (o.p)) rtrue; rfalse;\n");
	WRITE("];\n");
	WRITE("[ _final_write_eopval o p v t;\n");
	WRITE("    t = p-->0; p = p-->1; ! print \"give \", o, \" \", p, \"^\";\n");
	WRITE("    if (t == 2) { if (v) give o p; else give o ~p; }\n");
	WRITE("    else { if (o provides p) o.p = v; }\n");
	WRITE("];\n");
	WRITE("[ _final_message0 o p q x a rv;\n");
	WRITE("    ! print \"Message send \", (the) o, \" --> \", p, \" \", p-->1, \" addr \", o.(p-->1), \"^\";\n");
	WRITE("    q = p-->1; a = o.q; if (metaclass(a) == Object) rv = a; else if (a) { x = self; self = o; rv = indirect(a); self = x; } ! print \"Message = \", rv, \"^\";\n");
	WRITE("    return rv;\n");
	WRITE("];\n");
	WRITE("Constant i7_lvalue_SET = 1;\n");
	WRITE("Constant i7_lvalue_PREDEC = 2;\n");
	WRITE("Constant i7_lvalue_POSTDEC = 3;\n");
	WRITE("Constant i7_lvalue_PREINC = 4;\n");
	WRITE("Constant i7_lvalue_POSTINC = 5;\n");
	WRITE("Constant i7_lvalue_SETBIT = 6;\n");
	WRITE("Constant i7_lvalue_CLEARBIT = 7;\n");
	CodeGen::deselect(gen, saved);

