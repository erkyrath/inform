[CodeGen::] Code Generation.

To generate final code from intermediate code.

@h Pipeline stage.
This whole module exists to provide a single pipeline stage, making the final
generation of code from a tree of fully-linked and generally complete Inter.

It comes in two forms (the optional one writes nothing if no filename is supplied
to it; the compulsory one throws an error in that case), but note that both call
the same function.

=
void CodeGen::create_pipeline_stage(void) {
	CodeGen::Stage::new(I"generate", CodeGen::run_pipeline_stage,
		TEXT_OUT_STAGE_ARG, FALSE);
	CodeGen::Stage::new(I"optionally-generate", CodeGen::run_pipeline_stage, 
		OPTIONAL_TEXT_OUT_STAGE_ARG, FALSE);
}

@ Which is here. Three arguments can be supplied:
(a) The |generator_argument|: which code generator is to be used here. See
//Generators::make_all// for where the possibilities are set up.
(b) The |package_URL_argument|, which can tell us to generate code from just a
single package of the Inter tree, rather than the whole thing. Some generators
recognise this, but most do not, and generate from the whole tree regardless.
(c) The |to_stream| to write to.

=
int CodeGen::run_pipeline_stage(pipeline_step *step) {
	if (step->generator_argument) {
		code_generation *gen = CodeGen::new_generation(step->parsed_filename,
			step->to_stream, step->repository, step->package_argument,
			step->generator_argument, step->for_VM);
		Generators::go(gen);
	}
	return TRUE;
}

@ A "generation" is a single act of translating inter code into final code.
It will be carried out by the "generator", using the data held in the following
object.

=
typedef struct code_generation {
	struct code_generator *generator;
	struct target_vm *for_VM;
	void *generator_private_data; /* depending on the target generated to */

	struct filename *to_file;      /* filename of output, and/or... */
	struct text_stream *to_stream; /* stream for textual output */

	struct inter_tree *from;
	struct inter_package *just_this_package;

	struct segmentation_data segmentation;
	CLASS_DEFINITION
} code_generation;

code_generation *CodeGen::new_generation(filename *F, text_stream *T, inter_tree *I,
	inter_package *just, code_generator *generator, target_vm *VM) {
	code_generation *gen = CREATE(code_generation);
	gen->to_file = F;
	gen->to_stream = T;
	if ((VM == NULL) && (generator == NULL)) internal_error("no way to determine format");
	if (VM == NULL) VM = TargetVMs::find(generator->generator_name);
	gen->for_VM = VM;
	gen->from = I;
	gen->generator = generator;
	if (just) gen->just_this_package = just;
	else gen->just_this_package = Site::main_package(I);
	gen->segmentation = CodeGen::new_segmentation_data();
	return gen;
}

@h Segmentation.
Generators have flexibility in how they go about their business, but if they are
making what amounts to a text file with a lot of internal structure then the
following system may be a convenience. It allows text to be assembled as a set
of "segments" which can be appended to in any order, and which are then put
together in a logical order at the end.

Segments are identified by ID numbers counting up from 0, 1, 2, ...: one of
them, numbered 0, is the special "temporary" segment. This is used only as a
stash for text not going into the final output but needed for some intermediate
calculations. Sgements are, at present, just wrappers for tect streams, but one
could imagine them becoming more elaborate.

@e temporary_I7CGS from 0

=
typedef struct generated_segment {
	struct text_stream *generated_code;
	CLASS_DEFINITION
} generated_segment;

generated_segment *CodeGen::new_segment(void) {
	generated_segment *seg = CREATE(generated_segment);
	seg->generated_code = Str::new();
	return seg;
}

@ Each generation has its own copy of every possible numbered segment, though
by default those are |NULL|.

=
typedef struct segmentation_data {
	struct generated_segment *segments[NO_DEFINED_I7CGS_VALUES];
	struct linked_list *segment_sequence; /* of |generated_segment| */
	struct linked_list *additional_segment_sequence; /* of |generated_segment| */
	int temporarily_diverted; /* to the temporary segment */
	struct generated_segment *current_segment; /* the one currently being written to */
} segmentation_data;

segmentation_data CodeGen::new_segmentation_data(void) {
	segmentation_data sd;
	sd.current_segment = NULL;
	sd.segment_sequence = NEW_LINKED_LIST(generated_segment);
	sd.additional_segment_sequence = NEW_LINKED_LIST(generated_segment);
	sd.temporarily_diverted = FALSE;
	for (int i=0; i<NO_DEFINED_I7CGS_VALUES; i++) sd.segments[i] = NULL;
	return sd;
}

@ If a generator wants to use this system, it should call //CodeGen::create_segments//
to say which segments it wants to be created, passing an array of ID numbers. The
order of these is significant -- it's the order in which they will appear in the final
output.

=
void CodeGen::create_segments(code_generation *gen, void *data, int codes[]) {
	gen->segmentation.segment_sequence = NEW_LINKED_LIST(generated_segment);
	for (int i=0; codes[i] >= 0; i++) {
		if ((codes[i] >= NO_DEFINED_I7CGS_VALUES) ||
			(codes[i] == temporary_I7CGS)) internal_error("bad segment sequence");
		gen->segmentation.segments[codes[i]] = CodeGen::new_segment();
		ADD_TO_LINKED_LIST(gen->segmentation.segments[codes[i]], generated_segment,
			gen->segmentation.segment_sequence);
	}
	gen->generator_private_data = data;
}

@ An optional "alternative" set can also be created.

=
void CodeGen::additional_segments(code_generation *gen, int codes[]) {
	gen->segmentation.additional_segment_sequence = NEW_LINKED_LIST(generated_segment);
	for (int i=0; codes[i] >= 0; i++) {
		if ((codes[i] >= NO_DEFINED_I7CGS_VALUES) ||
			(codes[i] == temporary_I7CGS)) internal_error("bad segment sequence");
		gen->segmentation.segments[codes[i]] = CodeGen::new_segment();
		ADD_TO_LINKED_LIST(gen->segmentation.segments[codes[i]], generated_segment,
			gen->segmentation.additional_segment_sequence);
	}
}

@ At any given time, a generation has a "current" segment, to which output is
being written. The generator should use //CodeGen::select// to switch to a given
segment, which must be one of those it has created, and then use //CodeGen::deselect//
to go back to where it was. These calls must be made in properly nested pairs.

=
generated_segment *CodeGen::select(code_generation *gen, int i) {
	generated_segment *saved = gen->segmentation.current_segment;
	if ((i < 0) || (i >= NO_DEFINED_I7CGS_VALUES)) internal_error("out of range");
	if (gen->segmentation.temporarily_diverted) internal_error("poorly timed selection");
	gen->segmentation.current_segment = gen->segmentation.segments[i];
	if (gen->segmentation.current_segment == NULL)
		internal_error("generator does not use this segment ID");
	return saved;
}

void CodeGen::deselect(code_generation *gen, generated_segment *saved) {
	if (gen->segmentation.temporarily_diverted) internal_error("poorly timed deselection");
	gen->segmentation.current_segment = saved;
}

@ However, we can also temporarily divert the whole system to send its text to
some temporary stream somewhere. For that, use the following pair:

=
void CodeGen::select_temporary(code_generation *gen, text_stream *T) {
	if (gen->segmentation.segments[temporary_I7CGS] == NULL) {
		gen->segmentation.segments[temporary_I7CGS] = CodeGen::new_segment();
		gen->segmentation.segments[temporary_I7CGS]->generated_code = NULL;
	}
	if (gen->segmentation.temporarily_diverted) internal_error("nested temporary segments");
	gen->segmentation.temporarily_diverted = TRUE;
	gen->segmentation.segments[temporary_I7CGS]->generated_code = T;
}

void CodeGen::deselect_temporary(code_generation *gen) {
	gen->segmentation.temporarily_diverted = FALSE;
}

@ The following returns the text stream a generator should write to. Note that
if it has been "temporarily diverted" then the regiular selection is ignored.

=
text_stream *CodeGen::current(code_generation *gen) {
	if (gen->segmentation.temporarily_diverted)
		return gen->segmentation.segments[temporary_I7CGS]->generated_code;
	if (gen->segmentation.current_segment == NULL) return NULL;
	return gen->segmentation.current_segment->generated_code;
}

@ And then all we do is concatenate them in order:

=
void CodeGen::write_segments(OUTPUT_STREAM, code_generation *gen) {
	generated_segment *seg;
	LOOP_OVER_LINKED_LIST(seg, generated_segment, gen->segmentation.segment_sequence)
		WRITE("%S", seg->generated_code);
}

void CodeGen::write_additional_segments(OUTPUT_STREAM, code_generation *gen) {
	generated_segment *seg;
	LOOP_OVER_LINKED_LIST(seg, generated_segment, gen->segmentation.additional_segment_sequence)
		WRITE("%S", seg->generated_code);
}

text_stream *CodeGen::content(code_generation *gen, int i) {
	if ((i < 0) || (i >= NO_DEFINED_I7CGS_VALUES)) internal_error("out of range");
	return gen->segmentation.segments[i]->generated_code;
}

@h Transients.
One other optional service for the use of generators:

Transient flags on symbols are used temporarily during code generation, but do
not change the meaning of the tree: they're just a way to keep track of, say,
what we've worked on so far.

=
void CodeGen::clear_all_transients(inter_tree *I) {
	InterTree::traverse(I, CodeGen::clear_transients, NULL, NULL, PACKAGE_IST);
}

void CodeGen::clear_transients(inter_tree *I, inter_tree_node *P, void *state) {
	inter_package *pack = Inter::Package::defined_by_frame(P);
	inter_symbols_table *T = Inter::Packages::scope(pack);
	for (int i=0; i<T->size; i++)
		if (T->symbol_array[i])
			Inter::Symbols::clear_transient_flags(T->symbol_array[i]);
}

@ In particular the |TRAVERSE_MARK_BIT| flag is sometimes convenient to use.

=
int CodeGen::marked(inter_symbol *symb_name) {
	return Inter::Symbols::get_flag(symb_name, TRAVERSE_MARK_BIT);
}

void CodeGen::mark(inter_symbol *symb_name) {
	Inter::Symbols::set_flag(symb_name, TRAVERSE_MARK_BIT);
}

void CodeGen::unmark(inter_symbol *symb_name) {
	Inter::Symbols::clear_flag(symb_name, TRAVERSE_MARK_BIT);
}
