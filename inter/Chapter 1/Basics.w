[Basics::] Basics.

Some fundamental definitions.

@ Since we want to include the words module, we have to define the following
structure and initialiser:

@d VOCABULARY_MEANING_INITIALISER Basics::ignore

=
typedef struct vocabulary_meaning {
	int enigmatic_number;
} vocabulary_meaning;

vocabulary_meaning Basics::ignore(vocabulary_entry *ve) {
	vocabulary_meaning vm;
	vm.enigmatic_number = 16339;
	return vm;
}

@

@d LEXER_PROBLEM_HANDLER Basics::lexer_problem_handler

=
void Basics::lexer_problem_handler(int err, text_stream *problem_source_description, wchar_t *word) {
	if (err == MEMORY_OUT_LEXERERROR)
		Errors::fatal("Out of memory: unable to create lexer workspace");
	TEMPORARY_TEXT(word_t);
	if (word) WRITE_TO(word_t, "%w", word);
	switch (err) {
		case STRING_TOO_LONG_LEXERERROR:
			Errors::with_text("Too much text in quotation marks: %S", word_t);
            break;
		case WORD_TOO_LONG_LEXERERROR:
			Errors::with_text("Word too long: %S", word_t);
			break;
		case I6_TOO_LONG_LEXERERROR:
			Errors::with_text("I6 inclusion too long: %S", word_t);
			break;
		case STRING_NEVER_ENDS_LEXERERROR:
			Errors::with_text("Quoted text never ends: %S", problem_source_description);
			break;
		case COMMENT_NEVER_ENDS_LEXERERROR:
			Errors::with_text("Square-bracketed text never ends: %S", problem_source_description);
			break;
		case I6_NEVER_ENDS_LEXERERROR:
			Errors::with_text("I6 inclusion text never ends: %S", problem_source_description);
			break;
		default:
			internal_error("unknown lexer error");
    }
	DISCARD_TEXT(word_t);
}

@

= (early code)
typedef void kind;
kind *K_value = NULL;

@

@d PREFORM_LANGUAGE_TYPE void

@h Setting up the memory manager.
We need to itemise the structures we'll want to allocate:

@e inter_file_MT

@ And then expand:

=
ALLOCATE_INDIVIDUALLY(inter_file)
