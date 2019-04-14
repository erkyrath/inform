[Translation::] Translation.

@

=
typedef struct name_translation {
	struct text_stream *translate_to;
	int then_make_unique;
} name_translation;

name_translation Translation::same(void) {
	name_translation nt;
	nt.translate_to = NULL;
	nt.then_make_unique = FALSE;
	return nt;
}

name_translation Translation::uniqued(void) {
	name_translation nt;
	nt.translate_to = NULL;
	nt.then_make_unique = TRUE;
	return nt;
}

name_translation Translation::to(text_stream *S) {
	name_translation nt;
	nt.translate_to = S;
	nt.then_make_unique = FALSE;
	return nt;
}

name_translation Translation::to_uniqued(text_stream *S) {
	name_translation nt;
	nt.translate_to = S;
	nt.then_make_unique = TRUE;
	return nt;
}