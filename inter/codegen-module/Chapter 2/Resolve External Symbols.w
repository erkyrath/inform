[CodeGen::Externals::] Resolve External Symbols.

To make sure certain symbol names translate into globally unique target symbols.

@h Pipeline stage.

=
void CodeGen::Externals::create_pipeline_stage(void) {
	CodeGen::Stage::new(I"resolve-external-symbols", CodeGen::Externals::run_pipeline_stage, NO_STAGE_ARG, FALSE);
}

int CodeGen::Externals::run_pipeline_stage(pipeline_step *step) {
	Inter::Connectors::stecker(step->repository);
	int resolution_failed = FALSE;
	Inter::Tree::traverse(step->repository, CodeGen::Externals::visitor, &resolution_failed, NULL, PACKAGE_IST);
	if (resolution_failed) internal_error("undefined external link(s)");
	return TRUE;
}

void CodeGen::Externals::visitor(inter_tree *I, inter_tree_node *P, void *state) {
	int *fail_flag = (int *) state;
	inter_package *Q = Inter::Package::defined_by_frame(P);
	if (Inter::Tree::connectors_package(I) == Q) return;
	inter_symbols_table *ST = Inter::Packages::scope(Q);
	for (int i=0; i<ST->size; i++) {
		inter_symbol *S = ST->symbol_array[i];
		if ((S) && (S->equated_to)) {
			inter_symbol *D = S;
			while ((D) && (D->equated_to)) D = D->equated_to;
			S->equated_to = D;
			if (!Inter::Symbols::is_defined(D)) {
				inter_symbol *socket = Inter::Connectors::find_socket(I, D->symbol_name);
				if (socket) {
					D = socket->equated_to;
					S->equated_to = D;
				}
			}
			if (!Inter::Symbols::is_defined(D)) {
				if (Inter::Symbols::get_scope(D) == PLUG_ISYMS) {
					LOG("$3 == $3 which is a loose plug, seeking %S\n", S, D, D->equated_name);
					WRITE_TO(STDERR, "Failed to connect plug to: %S\n", D->equated_name);
					if (fail_flag) *fail_flag = TRUE;
				} else {
					LOG("$3 == $3 which is undefined\n", S, D);
					WRITE_TO(STDERR, "Failed to resolve symbol: %S\n", D->symbol_name);
					if (fail_flag) *fail_flag = TRUE;
				}
			}
		}
	}
}
