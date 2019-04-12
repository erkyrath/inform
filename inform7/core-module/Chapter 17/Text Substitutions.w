[Strings::TextSubstitutions::] Text Substitutions.

In this section we compile text with substitutions.

@h Definitions.

@ Text containing substitutions, such as "You pick up [the noun] thoughtfully.",
are compiled as routines rather than Z-machine strings. Each is stored in one
of the following structures. Unlike literal text, a text routine might lead
to problem messages when eventually compiled, so it is useful to record the
current sentence when a text routine is created: this means a problem can
be reported at the right place.

The easiest way to understand this section is to pretend that responses
don't exist, and ignore them until they come up later.

=
typedef struct text_substitution {
	struct wording unsubstituted_text; /* including the substitutions in squares */
	int dont_need_after_all; /* in case replaced as a response */
	int tr_done_already; /* has been compiled */
	struct rule *responding_to_rule;
	int responding_to_marker;
	struct parse_node *sentence_using_this; /* where this occurs in source */
	int local_names_existed_at_usage_time; /* remember in case of problems */
	struct ph_stack_frame *parked_stack_frame; /* for cases where possible */
	struct inter_name *ts_iname; /* the I6 array for this */
	struct inter_name *ts_routine_iname; /* the routine to implement it */
	int ts_sb_needed; /* reference copy of small block needed as a constant? */
	struct compilation_module *belongs_to_module;
	MEMORY_MANAGEMENT
} text_substitution;

@ We are only allowed to create new ones until the following is set:

=
int no_further_text_subs = FALSE;

@ The following global variable records whether we are currently compiling
a text routine, rather than some other routine, or free-standing objects.

= (early code)
int compiling_text_routines_mode = FALSE; /* used for better problem messages */

@ Like literal texts, text substitutions aren't printed out in full when
they first arise; we keep a note of them when we need them, and compile
suitable routines later.

A problem with this is that a text substitution probably contains references
to variables which exist now, but may not exist later when a routine to do
the printing is being compiled. For example,

>> say "The dial reads [counter].";

may do quite different things at different points in the code, according to
what |counter| currently means. So we need to take note of the current
stack frame; and we mustn't optimise by compiling identical text substitutions
to the same routines to print them.

=
text_substitution *Strings::TextSubstitutions::new_text_substitution(wording W,
	ph_stack_frame *phsf, rule *R, int marker, package_request *P) {
	text_substitution *ts = CREATE(text_substitution);
	if (no_further_text_subs) @<Panic, because it is really too late@>;
	ts->unsubstituted_text = Wordings::first_word(W);
	ts->sentence_using_this = current_sentence;
	ts->local_names_existed_at_usage_time = FALSE;
	if (R) {
		ts->parked_stack_frame = NULL;
	} else {
		ph_stack_frame new_frame = Frames::new();
		ts->parked_stack_frame = Frames::boxed_frame(&new_frame);
		if (phsf) LocalVariables::copy(ts->parked_stack_frame, phsf);
	}
	ts->responding_to_rule = R;
	ts->responding_to_marker = marker;
	ts->dont_need_after_all = FALSE;
	ts->tr_done_already = FALSE;
	ts->ts_sb_needed = FALSE;
	if ((phrase_being_compiled) &&
		(LocalVariables::count(Frames::current_stack_frame()) > 0))
		ts->local_names_existed_at_usage_time = TRUE;
	ts->ts_iname = Packaging::supply_iname(P, SUBSTITUTION_PR_COUNTER);
	//	InterNames::new_in(TEXT_SUBSTITUTION_INAMEF, Modules::current());
	ts->ts_routine_iname =
		Packaging::function(Packaging::supply_iname(P, SUBSTITUTIONF_PR_COUNTER), P, NULL);
	//	InterNames::new_derived(TEXT_ROUTINE_INAMEF, ts->ts_iname);
	ts->belongs_to_module = Modules::current();
	Inter::Symbols::set_flag(InterNames::to_symbol(ts->ts_iname), MAKE_NAME_UNIQUE);
	Inter::Symbols::set_flag(InterNames::to_symbol(ts->ts_routine_iname), MAKE_NAME_UNIQUE);
	LOGIF(TEXT_SUBSTITUTIONS, "Requesting text routine %d %08x %W %08x\n",
		ts->allocation_id, (int) phsf, W, R);
	return ts;
}

@ Timing is going to turn out to be a real problem in all of this code.
If Inform finds that it needs a text substitution very late in its run --
after it has compiled them and can't compile any more -- there's nothing
to do but panic.

@<Panic, because it is really too late@> =
	internal_error("Too late for further text substitutions");

@ The template layer calls the following when that midnight hour chimes:

=
void Strings::TextSubstitutions::allow_no_further_text_subs(void) {
	no_further_text_subs = TRUE;
}

@ For some years these were compiled to routines verbosely called
|text_routine_1| and so on, but no longer:

=
inter_name *Strings::TextSubstitutions::text_substitution_iname(text_substitution *ts) {
	if (ts->ts_sb_needed == FALSE) InterNames::to_symbol(ts->ts_iname);
	ts->ts_sb_needed = TRUE;
	return ts->ts_iname;
}

@ The following is called when we want to compile a usage of a text
substitution; for instance, when compiling

>> say "The time is [time of day]. Hurry!";

we'll compile a call to a routine like |TS_1()|, and make a note to compile
that routine later. This appearance of the routine name is called the "cue".

=
void Strings::TextSubstitutions::text_substitution_cue(value_holster *VH, wording W) {
	if (adopted_rule_for_compilation) {
		Rules::log(adopted_rule_for_compilation);
	}
	ph_stack_frame *phsf = NULL;
	if (adopted_rule_for_compilation) {
		@<Write the actual cue@>;
	} else {
		if (Holsters::data_acceptable(VH)) {
			int downs = 0;
			if (TEST_COMPILATION_MODE(PERMIT_LOCALS_IN_TEXT_CMODE)) {
				if (phsf == NULL) phsf = Frames::current_stack_frame();
				downs = LocalVariables::emit_storage(phsf);
				phsf = Frames::boxed_frame(phsf);
				Emit::inv_call(InterNames::to_symbol(Hierarchy::find(TEXT_TY_EXPANDIFPERISHABLE_HL)));
				Emit::down();
					Frames::emit_allocation(K_text);
			}
			text_substitution *ts = Strings::TextSubstitutions::new_text_substitution(W, phsf,
				adopted_rule_for_compilation, adopted_marker_for_compilation, Packaging::current_enclosure());
			inter_name *tin = Strings::TextSubstitutions::text_substitution_iname(ts);
			if (VH->vhmode_wanted == INTER_DATA_VHMODE)
				InterNames::holster(VH, tin);
			else
				Emit::val_iname(K_value, tin);
			if (TEST_COMPILATION_MODE(PERMIT_LOCALS_IN_TEXT_CMODE)) {
				Emit::up();
				while (downs > 0) { Emit::up(); downs--; }
			}
		}
	}
}

@<Write the actual cue@> =
	text_substitution *ts = Strings::TextSubstitutions::new_text_substitution(W, phsf,
		adopted_rule_for_compilation, adopted_marker_for_compilation, Packaging::current_enclosure());
	if (TEST_COMPILATION_MODE(CONSTANT_CMODE)) {
		packaging_state save = Packaging::enter_current_enclosure();
		inter_name *N = Kinds::RunTime::begin_block_constant(K_text);
		if (N) InterNames::holster(VH, N);
		Emit::array_iname_entry(Hierarchy::find(CONSTANT_PACKED_TEXT_STORAGE_HL));
		Emit::array_iname_entry(ts->ts_routine_iname);
		Kinds::RunTime::end_block_constant(K_text);
		Packaging::exit(save);
	} else {
		inter_name *tin = Strings::TextSubstitutions::text_substitution_iname(ts);
		if (Holsters::data_acceptable(VH)) {
			if (tin) InterNames::holster(VH, tin);
		}
	}

@ And the following clarifies problem messages arising from this point,
since it often confuses newcomers:

=
text_substitution *current_ts_being_compiled = NULL;

void Strings::TextSubstitutions::append_text_substitution_proviso(void) {
	if (it_is_not_worth_adding) return;
	if ((current_ts_being_compiled) &&
		(current_ts_being_compiled->local_names_existed_at_usage_time)) {
		Frames::log(Frames::current_stack_frame());
		Problems::quote_wording(9, current_ts_being_compiled->unsubstituted_text);
		Problems::issue_problem_segment(
			" %PIt may be worth adding that this problem arose in text "
			"which both contains substitutions and is also being used as "
			"a value - being put into a variable, or used as one of the "
			"ingredients in a phrase other than 'say'. Because that means "
			"it needs to be used in places outside its immediate context, "
			"it is not allowed to refer to any 'let' values or phrase "
			"options - those are temporary things, long gone by the time it "
			"would need to be printed.");
	}
}

@ So much for the cues. As with text literals in the previous section, it's
now time to redeem our promises and compile the |TS_X| routines. These routines
can't be produced all at once, and are sometimes not needed at all: the
responses mechanism makes this quite fiddly, and so do the existence of
other constructs in Inform which, when compiled, may make new text
substitutions. So compilation is handled by a coroutine. (I'm a
little old-fashioned in calling this a coroutine: it achieves its task in
instalments, effectively sharing time with other routines which in turn
add to its task, until everybody is done.)

Basically, we compile as many text substitutions as we can out of those not
yet done, returning the number we compile.

=
text_substitution *latest_ts_compiled = NULL;
int Strings::TextSubstitutions::compilation_coroutine(int in_response_mode) {
	Strings::compile_response_launchers();
	int N = 0;
	compiling_text_routines_mode = TRUE;
	while (TRUE) {
		text_substitution *ts;
		if (latest_ts_compiled == NULL) ts = FIRST_OBJECT(text_substitution);
		else ts = NEXT_OBJECT(latest_ts_compiled, text_substitution);
		if (ts == NULL) break;
		latest_ts_compiled = ts;
		int responding = FALSE;
		if (ts->responding_to_rule) responding = TRUE;
		if ((ts->dont_need_after_all == FALSE) && (responding == in_response_mode) &&
			(ts->tr_done_already == FALSE)) {
			Strings::TextSubstitutions::compile_single_substitution(ts);
		}
		N++;
	}

	compiling_text_routines_mode = FALSE;
	return N;
}

@ We can now forget about the coroutine management, and just compile a single
text substitution. The main thing is to copy over references to local variables
from the stack frame creating this text substitution to the stack frame
compiling it.

=
void Strings::TextSubstitutions::compile_single_substitution(text_substitution *ts) {
	LOGIF(TEXT_SUBSTITUTIONS, "Compiling text routine %d %08x %W\n",
		ts->allocation_id, (int) (ts->parked_stack_frame), ts->unsubstituted_text);

	current_ts_being_compiled = ts;
	ts->tr_done_already = TRUE;
	packaging_state save = Routines::begin(ts->ts_routine_iname);
	ph_stack_frame *phsf = ts->parked_stack_frame;
	if ((ts->responding_to_rule) && (ts->responding_to_marker >= 0)) {
		response_message *resp = Rules::rule_defines_response(
			ts->responding_to_rule, ts->responding_to_marker);
		if (resp) phsf = Strings::frame_for_response(resp);
	}
	if (phsf) LocalVariables::copy(Frames::current_stack_frame(), phsf);
	LocalVariables::monitor_local_parsing(Frames::current_stack_frame());

	@<Compile a say-phrase@>;

	int makes_local_references =
		LocalVariables::local_parsed_recently(Frames::current_stack_frame());
	if (makes_local_references) {
		Emit::push_code_position(Emit::begin_position());
		LocalVariables::compile_retrieval(phsf);
		Emit::pop_code_position();
	}
	Routines::end(save);

	if (ts->ts_sb_needed) {
		packaging_state save = Packaging::enter_home_of(ts->ts_iname);
		Emit::named_array_begin(ts->ts_iname, K_value);
		if (makes_local_references)
			Emit::array_iname_entry(Hierarchy::find(CONSTANT_PERISHABLE_TEXT_STORAGE_HL));
		else
			Emit::array_iname_entry(Hierarchy::find(CONSTANT_PACKED_TEXT_STORAGE_HL));
		Emit::array_iname_entry(ts->ts_routine_iname);
		Emit::array_end();
		Packaging::exit(save);
	}
	current_ts_being_compiled = NULL;
}

@ Of course, if we used Inform's standard phrase mechanism exactly, then
the whole thing would be circular, because that would once again generate
a request for a new text substitution to be compiled later...

@<Compile a say-phrase@> =
	BEGIN_COMPILATION_MODE;
	COMPILATION_MODE_EXIT(IMPLY_NEWLINES_IN_SAY_CMODE);

	if ((this_is_a_release_compile == FALSE) || (this_is_a_debug_compile)) {
		Emit::inv_primitive(ifdebug_interp);
		Emit::down();
			Emit::code();
			Emit::down();
				Emit::inv_primitive(if_interp);
				Emit::down();
					Emit::val_iname(K_number, Hierarchy::find(SUPPRESS_TEXT_SUBSTITUTION_HL));
					Emit::code();
					Emit::down();
						Emit::inv_primitive(print_interp);
						Emit::down();
							TEMPORARY_TEXT(S);
							WRITE_TO(S, "%W", ts->unsubstituted_text);
							Emit::val_text(S);
							DISCARD_TEXT(S);
						Emit::up();
						Emit::rtrue();
					Emit::up();
				Emit::up();
			Emit::up();
		Emit::up();
	}

	parse_node *ts_code_block = ParseTree::new(ROUTINE_NT);
	ParseTree::set_module(ts_code_block, ts->belongs_to_module);
	compilation_module *cm = Modules::current();
	Modules::set_current_to(ts->belongs_to_module);
	ts_code_block->down = ParseTree::new(INVOCATION_LIST_NT);
	ParseTree::set_text(ts_code_block->down, ts->unsubstituted_text);
	ParseTree::annotate_int(ts_code_block->down, from_text_substitution_ANNOT, TRUE);
	Sentences::RuleSubtrees::parse_routine_structure(ts_code_block);

	Routines::Compile::code_block_outer(0, ts_code_block->down);

	Emit::rtrue();

	END_COMPILATION_MODE;
	Modules::set_current_to(cm);

@ See the "Responses" section for why, but we sometimes want to force
the coroutine to go through the whole queue once, then go back to the
start again -- which would be very inefficient except that in this mode
we aren't doing very much; most TSs will be passed quickly over.

=
void Strings::TextSubstitutions::compile_text_routines_in_response_mode(void) {
	latest_ts_compiled = NULL;
	Strings::TextSubstitutions::compilation_coroutine(TRUE);
	latest_ts_compiled = NULL;
}
