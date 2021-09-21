[CodeGen::Textual::] Final Textual Inter.

To create the range of possible targets into which Inter can be converted.

@ This target is very simple: when we get the message to begin generation,
we simply ask the Inter module to output some text, and return true to
tell the generator that nothing more need be done.

=
void CodeGen::Textual::create_target(void) {
	code_generation_target *textual_inter_cgt = CodeGen::Targets::new(I"text");
	METHOD_ADD(textual_inter_cgt, BEGIN_GENERATION_MTID, CodeGen::Textual::text);
}

int CodeGen::Textual::text(code_generation_target *cgt, code_generation *gen) {
	if (gen->text_out_file) Inter::Textual::write(gen->text_out_file, gen->from, NULL, 1);
	return TRUE;
}
