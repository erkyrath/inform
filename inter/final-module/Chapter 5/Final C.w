[CTarget::] Final C.

Managing, or really just delegating, the generation of ANSI C code from a tree of Inter.

@h Target.

=
code_generation_target *c_target = NULL;
void CTarget::create_target(void) {
	c_target = CodeGen::Targets::new(I"c");

	METHOD_ADD(c_target, BEGIN_GENERATION_MTID, CTarget::begin_generation);
	METHOD_ADD(c_target, END_GENERATION_MTID, CTarget::end_generation);

	CProgramControl::initialise(c_target);
	CNamespace::initialise(c_target);
	CMemoryModel::initialise(c_target);
	CFunctionModel::initialise(c_target);
	CObjectModel::initialise(c_target);
	CLiteralsModel::initialise(c_target);
	CGlobals::initialise(c_target);
	CAssembly::initialise(c_target);
	CInputOutputModel::initialise(c_target);

	METHOD_ADD(c_target, GENERAL_SEGMENT_MTID, CTarget::general_segment);
	METHOD_ADD(c_target, TL_SEGMENT_MTID, CTarget::tl_segment);
	METHOD_ADD(c_target, DEFAULT_SEGMENT_MTID, CTarget::default_segment);
	METHOD_ADD(c_target, BASIC_CONSTANT_SEGMENT_MTID, CTarget::basic_constant_segment);
	METHOD_ADD(c_target, CONSTANT_SEGMENT_MTID, CTarget::constant_segment);
}

@h Static supporting code.
The C code generated here would not compile as a stand-alone file. It needs
to use variables and functions from a small unchanging library called 
|inform7_clib.h|. (The |.h| there is questionable, since this is not purely
a header file: it contains actual content and not only predeclarations. On
the other hand, it serves the same basic purpose.)

The code we generate here can only make sense if read alongside |inform7_clib.h|,
and vice versa, so the file is presented here in installments. This is the
first of those:

= (text to inform7_clib.h)
/* This is a library of C code to support Inform or other Inter programs compiled
   tp ANSI C. It was generated mechanically from the Inter source code, so to
   change it, edit that and not this. */

#ifndef I7_CLIB_H_INCLUDED
#define I7_CLIB_H_INCLUDED 1

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <ctype.h>
#include <stdint.h>
#include <setjmp.h>

typedef int32_t i7val;
typedef uint32_t i7uval;
typedef unsigned char i7byte;

#define I7_ASM_STACK_CAPACITY 128

typedef struct i7state {
	i7byte *memory;
	i7val himem;
	i7val stack[I7_ASM_STACK_CAPACITY];
	int stack_pointer;
	i7val *i7_object_tree_parent;
	i7val *i7_object_tree_child;
	i7val *i7_object_tree_sibling;
	i7val *variables;
	i7val tmp;
} i7state;

typedef struct i7snapshot {
	int valid;
	struct i7state then;
	jmp_buf env;
} i7snapshot;

#define I7_MAX_SNAPSHOTS 10

typedef struct i7process {
	i7state state;
	i7snapshot snapshots[I7_MAX_SNAPSHOTS];
	int snapshot_pos;
	jmp_buf execution_env;
	int termination_code;
	int just_undid;
} i7process;

i7state i7_new_state(void);
i7process i7_new_process(void);
i7snapshot i7_new_snapshot(void);
void i7_save_snapshot(i7process *proc);
int i7_has_snapshot(i7process *proc);
void i7_restore_snapshot(i7process *proc);
void i7_restore_snapshot_from(i7process *proc, i7snapshot *ss);
void i7_destroy_latest_snapshot(i7process *proc);
void i7_run_process(i7process *proc, void (*receiver)(int id, wchar_t c));
void i7_initializer(i7process *proc);
void i7_fatal_exit(i7process *proc);
void i7_destroy_state(i7process *proc, i7state *s);
void i7_destroy_snapshot(i7process *proc, i7snapshot *old);
void i7_default_receiver(int id, wchar_t c);
=

= (text to inform7_clib.c)
#ifndef I7_CLIB_C_INCLUDED
#define I7_CLIB_C_INCLUDED 1

i7state i7_new_state(void) {
	i7state S;
	S.memory = NULL;
	S.himem = 0;
	S.tmp = 0;
	S.stack_pointer = 0;
	S.i7_object_tree_parent = NULL;
	S.i7_object_tree_child = NULL;
	S.i7_object_tree_sibling = NULL;
	S.variables = NULL;
	return S;
}

void i7_copy_state(i7process *proc, i7state *to, i7state *from) {
	to->himem = from->himem;
	to->memory = calloc(i7_static_himem, sizeof(i7byte));
	if (to->memory == NULL) { 
		printf("Memory allocation failed\n");
		i7_fatal_exit(proc);
	}
	for (int i=0; i<i7_static_himem; i++) to->memory[i] = from->memory[i];
	to->tmp = from->tmp;
	to->stack_pointer = from->stack_pointer;
	for (int i=0; i<from->stack_pointer; i++) to->stack[i] = from->stack[i];
	to->i7_object_tree_parent  = calloc(i7_max_objects, sizeof(i7val));
	to->i7_object_tree_child   = calloc(i7_max_objects, sizeof(i7val));
	to->i7_object_tree_sibling = calloc(i7_max_objects, sizeof(i7val));
	
	if ((to->i7_object_tree_parent == NULL) ||
		(to->i7_object_tree_child == NULL) ||
		(to->i7_object_tree_sibling == NULL)) {
		printf("Memory allocation failed\n");
		i7_fatal_exit(proc);
	}
	for (int i=0; i<i7_max_objects; i++) {
		to->i7_object_tree_parent[i] = from->i7_object_tree_parent[i];
		to->i7_object_tree_child[i] = from->i7_object_tree_child[i];
		to->i7_object_tree_sibling[i] = from->i7_object_tree_sibling[i];
	}
	to->variables = calloc(i7_no_variables, sizeof(i7val));
	if (to->variables == NULL) { 
		printf("Memory allocation failed\n");
		i7_fatal_exit(proc);
	}
	for (int i=0; i<i7_no_variables; i++)
		to->variables[i] = from->variables[i];
}

void i7_destroy_state(i7process *proc, i7state *s) {
	free(s->memory);
	s->himem = 0;
	free(s->i7_object_tree_parent);
	free(s->i7_object_tree_child);
	free(s->i7_object_tree_sibling);
	s->stack_pointer = 0;
	free(s->variables);
}

void i7_destroy_snapshot(i7process *proc, i7snapshot *old) {
	i7_destroy_state(proc, &(old->then));
	old->valid = 0;
}

i7snapshot i7_new_snapshot(void) {
	i7snapshot SS;
	SS.valid = 0;
	SS.then = i7_new_state();
	return SS;
}

i7process i7_new_process(void) {
	i7process proc;
	proc.state = i7_new_state();
	for (int i=0; i<I7_MAX_SNAPSHOTS; i++) proc.snapshots[i] = i7_new_snapshot();
	proc.just_undid = 0;
	proc.snapshot_pos = 0;
	return proc;
}

void i7_save_snapshot(i7process *proc) {
	if (proc->snapshots[proc->snapshot_pos].valid)
		i7_destroy_snapshot(proc, &(proc->snapshots[proc->snapshot_pos]));
	proc->snapshots[proc->snapshot_pos] = i7_new_snapshot();
	proc->snapshots[proc->snapshot_pos].valid = 1;
	i7_copy_state(proc, &(proc->snapshots[proc->snapshot_pos].then), &(proc->state));
	int was = proc->snapshot_pos;
	proc->snapshot_pos++;
	if (proc->snapshot_pos == I7_MAX_SNAPSHOTS) proc->snapshot_pos = 0;
//	if (setjmp(proc->snapshots[was].env)) fprintf(stdout, "*** Restore! %d ***\n", proc->just_undid);
}

int i7_has_snapshot(i7process *proc) {
	int will_be = proc->snapshot_pos - 1;
	if (will_be < 0) will_be = I7_MAX_SNAPSHOTS - 1;
	return proc->snapshots[will_be].valid;
}

void i7_destroy_latest_snapshot(i7process *proc) {
	int will_be = proc->snapshot_pos - 1;
	if (will_be < 0) will_be = I7_MAX_SNAPSHOTS - 1;
	if (proc->snapshots[will_be].valid)
		i7_destroy_snapshot(proc, &(proc->snapshots[will_be]));
	proc->snapshot_pos = will_be;
}

void i7_restore_snapshot(i7process *proc) {
	int will_be = proc->snapshot_pos - 1;
	if (will_be < 0) will_be = I7_MAX_SNAPSHOTS - 1;
	if (proc->snapshots[will_be].valid == 0) {
		printf("Restore impossible\n");
		i7_fatal_exit(proc);
	}
	i7_restore_snapshot_from(proc, &(proc->snapshots[will_be]));
	i7_destroy_snapshot(proc, &(proc->snapshots[will_be]));
	int was = proc->snapshot_pos;
	proc->snapshot_pos = will_be;
//	longjmp(proc->snapshots[was].env, 1);
}

void i7_restore_snapshot_from(i7process *proc, i7snapshot *ss) {
	i7_destroy_state(proc, &(proc->state));
	i7_copy_state(proc, &(proc->state), &(ss->then));
}

void i7_default_receiver(int id, wchar_t c) {
	if (id == 201) fputc(c, stdout);
}

#ifndef I7_NO_MAIN
int main(int argc, char **argv) {
	i7process proc = i7_new_process();
	i7_run_process(&proc, i7_default_receiver);
	if (proc.termination_code == 1) {
		printf("*** Fatal error: halted ***\n");
		fflush(stdout); fflush(stderr);
	}
	return proc.termination_code;
}
#endif

i7val fn_i7_mgl_Main(i7process *proc);
void i7_run_process(i7process *proc, void (*receiver)(int id, wchar_t c)) {
	if (setjmp(proc->execution_env)) {
		proc->termination_code = 1; /* terminated abnormally */
    } else {
		i7_initialise_state(proc);
		i7_initializer(proc);
		i7_initialise_streams(proc, receiver);
		fn_i7_mgl_Main(proc);
		proc->termination_code = 0; /* terminated normally */
    }
}

void i7_fatal_exit(i7process *proc) {
//	int x = 0; printf("%d", 1/x);
	longjmp(proc->execution_env, 1);
}
=

@h Segmentation.

@e c_header_inclusion_I7CGS
@e c_ids_and_maxima_I7CGS
@e c_library_inclusion_I7CGS
@e c_predeclarations_I7CGS
@e c_very_early_matter_I7CGS
@e c_constants_1_I7CGS
@e c_constants_2_I7CGS
@e c_constants_3_I7CGS
@e c_constants_4_I7CGS
@e c_constants_5_I7CGS
@e c_constants_6_I7CGS
@e c_constants_7_I7CGS
@e c_constants_8_I7CGS
@e c_constants_9_I7CGS
@e c_constants_10_I7CGS
@e c_early_matter_I7CGS
@e c_text_literals_code_I7CGS
@e c_summations_at_eof_I7CGS
@e c_arrays_at_eof_I7CGS
@e c_main_matter_I7CGS
@e c_functions_at_eof_I7CGS
@e c_code_at_eof_I7CGS
@e c_verbs_at_eof_I7CGS
@e c_stubs_at_eof_I7CGS
@e c_property_offset_creator_I7CGS
@e c_mem_I7CGS
@e c_globals_array_I7CGS
@e c_initialiser_I7CGS

=
int C_target_segments[] = {
	c_header_inclusion_I7CGS,
	c_ids_and_maxima_I7CGS,
	c_library_inclusion_I7CGS,
	c_predeclarations_I7CGS,
	c_very_early_matter_I7CGS,
	c_constants_1_I7CGS,
	c_constants_2_I7CGS,
	c_constants_3_I7CGS,
	c_constants_4_I7CGS,
	c_constants_5_I7CGS,
	c_constants_6_I7CGS,
	c_constants_7_I7CGS,
	c_constants_8_I7CGS,
	c_constants_9_I7CGS,
	c_constants_10_I7CGS,
	c_early_matter_I7CGS,
	c_text_literals_code_I7CGS,
	c_summations_at_eof_I7CGS,
	c_arrays_at_eof_I7CGS,
	c_main_matter_I7CGS,
	c_functions_at_eof_I7CGS,
	c_code_at_eof_I7CGS,
	c_verbs_at_eof_I7CGS,
	c_stubs_at_eof_I7CGS,
	c_property_offset_creator_I7CGS,
	c_mem_I7CGS,
	c_globals_array_I7CGS,
	c_initialiser_I7CGS,
	-1
};

@h State data.

@d C_GEN_DATA(x) ((C_generation_data *) (gen->target_specific_data))->x

=
typedef struct C_generation_data {
	struct C_generation_memory_model_data memdata;
	struct C_generation_function_model_data fndata;
	struct C_generation_object_model_data objdata;
	struct C_generation_literals_model_data litdata;
	CLASS_DEFINITION
} C_generation_data;

void CTarget::initialise_data(code_generation *gen) {
	CMemoryModel::initialise_data(gen);
	CFunctionModel::initialise_data(gen);
	CObjectModel::initialise_data(gen);
	CLiteralsModel::initialise_data(gen);
	CGlobals::initialise_data(gen);
	CAssembly::initialise_data(gen);
	CInputOutputModel::initialise_data(gen);
}

@h Begin and end.

=
int CTarget::begin_generation(code_generation_target *cgt, code_generation *gen) {
	CodeGen::create_segments(gen, CREATE(C_generation_data), C_target_segments);
	CTarget::initialise_data(gen);

	CNamespace::fix_locals(gen);

	generated_segment *saved = CodeGen::select(gen, c_header_inclusion_I7CGS);
	text_stream *OUT = CodeGen::current(gen);
	WRITE("#include \"inform7_clib.h\"\n");
	CodeGen::deselect(gen, saved);

	saved = CodeGen::select(gen, c_library_inclusion_I7CGS);
	OUT = CodeGen::current(gen);
	WRITE("#include \"inform7_clib.c\"\n");
	CodeGen::deselect(gen, saved);

	CMemoryModel::begin(gen);
	CFunctionModel::begin(gen);
	CObjectModel::begin(gen);
	CLiteralsModel::begin(gen);
	CGlobals::begin(gen);
	CAssembly::begin(gen);
	CInputOutputModel::begin(gen);

	return FALSE;
}

int CTarget::end_generation(code_generation_target *cgt, code_generation *gen) {
	CFunctionModel::end(gen);
	CObjectModel::end(gen);
	CLiteralsModel::end(gen);
	CGlobals::end(gen);
	CAssembly::end(gen);
	CInputOutputModel::end(gen);
	CMemoryModel::end(gen); /* must be last to end */

	return FALSE;
}

int CTarget::general_segment(code_generation_target *cgt, code_generation *gen, inter_tree_node *P) {
	switch (P->W.data[ID_IFLD]) {
		case CONSTANT_IST: {
			inter_symbol *con_name =
				InterSymbolsTables::symbol_from_frame_data(P, DEFN_CONST_IFLD);
			int choice = c_early_matter_I7CGS;
			if (Str::eq(con_name->symbol_name, I"DynamicMemoryAllocation")) choice = c_very_early_matter_I7CGS;
			if (Inter::Symbols::read_annotation(con_name, LATE_IANN) == 1) choice = c_code_at_eof_I7CGS;
			if (Inter::Symbols::read_annotation(con_name, BUFFERARRAY_IANN) == 1) choice = c_arrays_at_eof_I7CGS;
			if (Inter::Symbols::read_annotation(con_name, BYTEARRAY_IANN) == 1) choice = c_arrays_at_eof_I7CGS;
			if (Inter::Symbols::read_annotation(con_name, TABLEARRAY_IANN) == 1) choice = c_arrays_at_eof_I7CGS;
			if (P->W.data[FORMAT_CONST_IFLD] == CONSTANT_INDIRECT_LIST) choice = c_arrays_at_eof_I7CGS;
			if (Inter::Symbols::read_annotation(con_name, VERBARRAY_IANN) == 1) choice = c_verbs_at_eof_I7CGS;
			if (Inter::Constant::is_routine(con_name)) choice = c_functions_at_eof_I7CGS;
			return choice;
		}
	}
	return CTarget::default_segment(cgt);
}

int CTarget::default_segment(code_generation_target *cgt) {
	return c_main_matter_I7CGS;
}
int CTarget::constant_segment(code_generation_target *cgt, code_generation *gen) {
	return c_early_matter_I7CGS;
}
int CTarget::basic_constant_segment(code_generation_target *cgt, code_generation *gen, inter_symbol *con_name, int depth) {
	if (Str::eq(CodeGen::CL::name(con_name), I"Release")) return c_ids_and_maxima_I7CGS;
	if (Str::eq(CodeGen::CL::name(con_name), I"Serial")) return c_ids_and_maxima_I7CGS;
	if (depth >= 10) depth = 10;
	return c_constants_1_I7CGS + depth - 1;
}
int CTarget::tl_segment(code_generation_target *cgt) {
	return c_text_literals_code_I7CGS;
}
