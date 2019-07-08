[Inter::Packages::] Packages.

To manage packages of inter code.

@h Symbols tables.

=
typedef struct inter_package {
	struct inter_repository *stored_in;
	inter_t index_n;
	struct inter_symbol *package_name;
	struct inter_package *parent_package;
	struct inter_package *child_package;
	struct inter_package *next_package;
	struct inter_symbols_table *package_scope;
	int codelike_package;
	inter_t I7_baseline;
	int package_flags;
	MEMORY_MANAGEMENT
} inter_package;

@

@d EXCLUDE_PACKAGE_FLAG 1
@d USED_PACKAGE_FLAG 2

@ =
inter_package *Inter::Packages::new(inter_package *par, inter_repository *I, inter_t n) {
	inter_package *pack = CREATE(inter_package);
	pack->stored_in = I;
	pack->package_scope = NULL;
	pack->package_name = NULL;
	pack->package_flags = 0;
	pack->parent_package = par;
	if (par) {
		if (par->child_package == NULL) par->child_package = pack;
		else {
			inter_package *sib = par->child_package;
			while ((sib) && (sib->next_package)) sib = sib->next_package;
			sib->next_package = pack;
		}
	}
	pack->index_n = n;
	pack->codelike_package = FALSE;
	pack->I7_baseline = 0;
	return pack;
}

void Inter::Packages::set_scope(inter_package *P, inter_symbols_table *T) {
	if (P == NULL) internal_error("null package");
	P->package_scope = T;
	if (T) T->owning_package = P;
}

void Inter::Packages::set_name(inter_package *P, inter_symbol *N) {
	if (P == NULL) internal_error("null package");
	if (N == NULL) internal_error("null package name");
	P->package_name = N;
	if ((N) && (Str::eq(N->symbol_name, I"main"))) {
		P->stored_in->main_package = P;
	}
}

void Inter::Packages::log(OUTPUT_STREAM, void *vp) {
	inter_package *pack = (inter_package *) vp;
	if (pack == NULL) WRITE("<null-package>");
	else {
		WRITE("%S", pack->package_name->symbol_name);
	}
}

inter_package *Inter::Packages::main(inter_repository *I) {
	if (I) return I->main_package;
	return NULL;
}

inter_package *Inter::Packages::basics(inter_repository *I) {
	inter_symbol *S = Inter::Packages::search_main_exhaustively(I, I"basics");
	if (S) return Inter::Package::which(S);
	return NULL;
}

inter_package *Inter::Packages::veneer(inter_repository *I) {
	inter_symbol *S = Inter::Packages::search_main_exhaustively(I, I"veneer");
	if (S) return Inter::Package::which(S);
	return NULL;
}

inter_package *Inter::Packages::template(inter_repository *I) {
	inter_symbol *S = Inter::Packages::search_main_exhaustively(I, I"template");
	if (S) return Inter::Package::which(S);
	return NULL;
}

inter_symbol *Inter::Packages::search_exhaustively(inter_package *P, text_stream *S) {
	inter_symbol *found = Inter::SymbolsTables::symbol_from_name(Inter::Packages::scope(P), S);
	if (found) return found;
	for (P = P->child_package; P; P = P->next_package) {
		found = Inter::Packages::search_exhaustively(P, S);
		if (found) return found;
	}
	return NULL;
}

inter_symbol *Inter::Packages::search_main_exhaustively(inter_repository *I, text_stream *S) {
	return Inter::Packages::search_exhaustively(Inter::Packages::main(I), S);
}

inter_symbol *Inter::Packages::search_resources_exhaustively(inter_repository *I, text_stream *S) {
	for (inter_package *P = Inter::Packages::main(I)->child_package; P; P = P->next_package) {
		inter_symbol *found = Inter::Packages::search_exhaustively(P, S);
		if (found) return found;
	}
	return NULL;
}

inter_t Inter::Packages::to_PID(inter_package *P) {
	if (P == NULL) return 0;
	return P->index_n;
}

inter_package *Inter::Packages::from_PID(inter_repository *I, inter_t PID) {
	if (PID == 0) return NULL;
	return Inter::get_package(I, PID);
}

inter_package *Inter::Packages::container(inter_frame P) {
	if (P.repo_segment == NULL) return NULL;
	return Inter::Packages::from_PID(P.repo_segment->owning_repo, Inter::Frame::get_package(P));
}

inter_package *Inter::Packages::container_p(inter_frame *P) {
	if (P->repo_segment == NULL) return NULL;
	return Inter::Packages::from_PID(P->repo_segment->owning_repo, Inter::Frame::get_package_p(P));
}

void Inter::Packages::restring(inter_repository *I) {
	Inter::Packages::destring(Inter::Packages::main(I));
	inter_frame P;
	LOOP_THROUGH_INTER_FRAME_LIST(P, (&(I->residue))) {
		inter_package *pack = Inter::Packages::container(P);
		if ((pack) && (pack->codelike_package == FALSE)) {
			inter_frame D = Inter::Symbols::defining_frame(pack->package_name);
			Inter::Defn::accept_child(D, P, FALSE);
		}
	}
}

void Inter::Packages::destring(inter_package *pack) {
	if (pack->codelike_package == FALSE) {
		inter_frame_list *ifl = Inter::Package::code_list(pack->package_name);
		ifl->first_in_ifl = NULL;
		ifl->last_in_ifl = NULL;
	}
	for (inter_package *P = pack->child_package; P; P = P->next_package)
		Inter::Packages::destring(P);
}

void Inter::Packages::traverse_global(code_generation *gen, void (*visitor)(code_generation *, inter_frame, void *), void *state) {
	inter_frame P;
	LOOP_THROUGH_INTER_FRAME_LIST(P, (&(gen->from->global_material))) {
		if (Inter::Packages::container(P)) return;
		if (P.data[ID_IFLD] != PACKAGE_IST) {
			(*visitor)(gen, P, state);
		}
	}
}

void Inter::Packages::traverse_global_inc(code_generation *gen, void (*visitor)(code_generation *, inter_frame, void *), void *state) {
	inter_frame P;
	LOOP_THROUGH_INTER_FRAME_LIST(P, (&(gen->from->global_material))) {
		if (Inter::Packages::container(P)) return;
		(*visitor)(gen, P, state);
	}
}

void Inter::Packages::traverse_repository_global(inter_repository *from, void (*visitor)(inter_repository *, inter_frame, void *), void *state) {
	inter_frame P;
	LOOP_THROUGH_INTER_FRAME_LIST(P, (&(from->global_material))) {
		if (Inter::Packages::container(P)) return;
		if (P.data[ID_IFLD] != PACKAGE_IST) {
			(*visitor)(from, P, state);
		}
	}
}

void Inter::Packages::traverse_repository_global_inc(inter_repository *from, void (*visitor)(inter_repository *, inter_frame, void *), void *state) {
	inter_frame P;
	LOOP_THROUGH_INTER_FRAME_LIST(P, (&(from->global_material))) {
		if (Inter::Packages::container(P)) return;
		(*visitor)(from, P, state);
	}
}

void Inter::Packages::traverse(code_generation *gen, void (*visitor)(code_generation *, inter_frame, void *), void *state) {
	Inter::Packages::traverse_inner(gen, Inter::Packages::contents(gen->just_this_package), visitor, state);
}
void Inter::Packages::traverse_inner(code_generation *gen, inter_frame_list *ifl, void (*visitor)(code_generation *, inter_frame, void *), void *state) {
	if (ifl) {
		inter_frame P;
		LOOP_THROUGH_INTER_FRAME_LIST(P, ifl) {
			if (P.data[ID_IFLD] != PACKAGE_IST)
				(*visitor)(gen, P, state);
			inter_frame_list *ifl = Inter::Defn::list_of_children(P);
			if (ifl) Inter::Packages::traverse_inner(gen, ifl, visitor, state);
//			if (P.data[ID_IFLD] == PACKAGE_IST) {
//				inter_frame_list *ifl = Inter::Defn::list_of_children(P);
//				if (ifl) Inter::Packages::traverse_inner(gen, ifl, visitor, state);
//			} else {
//				(*visitor)(gen, P, state);
//			}
		}
	}
}

void Inter::Packages::traverse_repository(inter_repository *from, void (*visitor)(inter_repository *, inter_frame, void *), void *state) {
	Inter::Packages::traverse_repository_inner(from, Inter::Packages::contents(Inter::Packages::main(from)), visitor, state);
}
void Inter::Packages::traverse_repository_inner(inter_repository *from, inter_frame_list *ifl, void (*visitor)(inter_repository *, inter_frame, void *), void *state) {
	if (ifl) {
		inter_frame P;
		LOOP_THROUGH_INTER_FRAME_LIST(P, ifl) {
			if (P.data[ID_IFLD] != PACKAGE_IST)
				(*visitor)(from, P, state);
			inter_frame_list *ifl = Inter::Defn::list_of_children(P);
			if (ifl) Inter::Packages::traverse_repository_inner(from, ifl, visitor, state);
//			if (P.data[ID_IFLD] == PACKAGE_IST) {
//				inter_frame_list *ifl = Inter::Defn::list_of_children(P);
//				if (ifl) Inter::Packages::traverse_repository_inner(from, ifl, visitor, state);
//			} else {
//				(*visitor)(from, P, state);
//			}
		}
	}
}

void Inter::Packages::traverse_repository_inc(inter_repository *from, void (*visitor)(inter_repository *, inter_frame, void *), void *state) {
	Inter::Packages::traverse_repository_inc_inner(from, Inter::Packages::contents(Inter::Packages::main(from)), visitor, state);
}
void Inter::Packages::traverse_repository_inc_inner(inter_repository *from, inter_frame_list *ifl, void (*visitor)(inter_repository *, inter_frame, void *), void *state) {
	if (ifl) {
		inter_frame P;
		LOOP_THROUGH_INTER_FRAME_LIST(P, ifl) {
			(*visitor)(from, P, state);
//			if (P.data[ID_IFLD] == PACKAGE_IST) {
				inter_frame_list *ifl = Inter::Defn::list_of_children(P);
				if (ifl) Inter::Packages::traverse_repository_inc_inner(from, ifl, visitor, state);
//			}
		}
	}
}

void Inter::Packages::traverse_repository_e(inter_repository *from, void (*visitor)(inter_repository *, inter_frame, void *, inter_frame_list_entry *), void *state) {
	Inter::Packages::traverse_repository_inner_e(from, Inter::Packages::contents(Inter::Packages::main(from)), visitor, state);
}
void Inter::Packages::traverse_repository_inner_e(inter_repository *from, inter_frame_list *ifl, void (*visitor)(inter_repository *, inter_frame, void *, inter_frame_list_entry *), void *state) {
	if (ifl) {
		inter_frame P;
		LOOP_THROUGH_INTER_FRAME_LIST(P, ifl) {
			if (P.data[ID_IFLD] != PACKAGE_IST)
				(*visitor)(from, P, state, P_entry);
			inter_frame_list *ifl = Inter::Defn::list_of_children(P);
			if (ifl) Inter::Packages::traverse_repository_inner_e(from, ifl, visitor, state);
//			if (P.data[ID_IFLD] == PACKAGE_IST) {
//				inter_frame_list *ifl = Inter::Defn::list_of_children(P);
//				if (ifl) Inter::Packages::traverse_repository_inner_e(from, ifl, visitor, state);
//			} else {
//				(*visitor)(from, P, state, P_entry);
//			}
		}
	}
}

inter_symbols_table *Inter::Packages::scope(inter_package *pack) {
	if (pack == NULL) return NULL;
	return pack->package_scope;
}

inter_symbols_table *Inter::Packages::scope_of(inter_frame P) {
	inter_package *pack = Inter::Packages::container(P);
	if (pack) return pack->package_scope;
	return Inter::Frame::global_symbols(P);
}

inter_symbol *Inter::Packages::type(inter_package *P) {
	if (P == NULL) return NULL;
	if (P->package_name == NULL) return NULL;
	return Inter::Package::type(P->package_name);
}

int Inter::Packages::baseline(inter_package *P) {
	if (P == NULL) return 0;
	if (P->package_name == NULL) return 0;
	return Inter::Defn::get_level(Inter::Symbols::defining_frame(P->package_name));
}

inter_frame_list *Inter::Packages::contents(inter_package *P) {
	if (P == NULL) return NULL;
	return Inter::Package::code_list(P->package_name);
}
