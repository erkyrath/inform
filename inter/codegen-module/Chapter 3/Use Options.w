[SynopticUseOptions::] Use Options.

To compile the main/synoptic/use_options submodule.

@ As this is called, //Synoptic Utilities// has already formed a list |use_option_nodes|
of packages of type |_use_option|.

=
void SynopticUseOptions::compile(inter_tree *I) {
	if (TreeLists::len(use_option_nodes) > 0) {
		TreeLists::sort(use_option_nodes, Synoptic::module_order);
		for (int i=0; i<TreeLists::len(use_option_nodes); i++) {
			inter_package *pack = Inter::Package::defined_by_frame(use_option_nodes->list[i].node);
			inter_tree_node *D = Synoptic::get_definition(pack, I"use_option_id");
			D->W.data[DATA_CONST_IFLD+1] = (inter_ti) i;
		}
	}

	@<Define NO_USE_OPTIONS@>;
	@<Define TESTUSEOPTION function@>;
	@<Define PRINT_USE_OPTION function@>;
}

@<Define NO_USE_OPTIONS@> =
	inter_name *iname = HierarchyLocations::find(I, NO_USE_OPTIONS_HL);
	Produce::numeric_constant(I, iname, K_value, (inter_ti) (TreeLists::len(use_option_nodes)));

@ A relatively late addition to the design of use options was to make them
values at runtime, of the kind "use option". We need to provide two functions:
one to test whether a given use option is currently set, one to print the
name of a given use option.

@<Define TESTUSEOPTION function@> =
	inter_name *iname = HierarchyLocations::find(I, TESTUSEOPTION_HL);
	Synoptic::begin_function(I, iname);
	inter_symbol *UO_s = Synoptic::local(I, I"UO", NULL);
	for (int i=0; i<TreeLists::len(use_option_nodes); i++) {
		inter_package *pack = Inter::Package::defined_by_frame(use_option_nodes->list[i].node);
		inter_ti set = Metadata::read_numeric(pack, I"^active");
		if (set) {
			Produce::inv_primitive(I, IF_BIP);
			Produce::down(I);
				Produce::inv_primitive(I, EQ_BIP);
				Produce::down(I);
					Produce::val_symbol(I, K_value, UO_s);
					Produce::val(I, K_value, LITERAL_IVAL, (inter_ti) i);
				Produce::up(I);
				Produce::code(I);
				Produce::down(I);
					Produce::rtrue(I);
				Produce::up(I);
			Produce::up(I);
		}
	}
	Produce::rfalse(I);
	Synoptic::end_function(I, iname);

@<Define PRINT_USE_OPTION function@> =
	inter_name *iname = HierarchyLocations::find(I, PRINT_USE_OPTION_HL);
	Synoptic::begin_function(I, iname);
	inter_symbol *UO_s = Synoptic::local(I, I"UO", NULL);
	Produce::inv_primitive(I, SWITCH_BIP);
	Produce::down(I);
		Produce::val_symbol(I, K_value, UO_s);
		Produce::code(I);
		Produce::down(I);
			for (int i=0; i<TreeLists::len(use_option_nodes); i++) {
				inter_package *pack = Inter::Package::defined_by_frame(use_option_nodes->list[i].node);
				text_stream *printed_name = Metadata::read_textual(pack, I"^printed_name");
				Produce::inv_primitive(I, CASE_BIP);
				Produce::down(I);
					Produce::val(I, K_value, LITERAL_IVAL, (inter_ti) i);
					Produce::code(I);
					Produce::down(I);
						Produce::inv_primitive(I, PRINT_BIP);
						Produce::down(I);
							Produce::val_text(I, printed_name);
						Produce::up(I);
					Produce::up(I);
				Produce::up(I);
			}
		Produce::up(I);
	Produce::up(I);
	Synoptic::end_function(I, iname);
