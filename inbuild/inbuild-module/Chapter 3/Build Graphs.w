[Graphs::] Build Graphs.

Graphs in which vertices correspond to files or copies, and edges to
dependencies between them.

@h Build graphs.
See the Inbuild manual for an introduction to the build graph. Properly
speaking, it is a directed acyclic multigraph which us usually disconnected.

There are two colours of edge: build edges and use edges. A build edge between
A and B means that B must exist and be up-to-date before A can be built.
A use edge between A and B means that B must exist and be up-to-date before
A can be used.

There are three colours of vertex: copy, file and requirement. Copy vertices
correspond to copies which the user does have; requirement vertices to copies
which she doesn't have; and file vertices to unmanaged plain files in
the build process. For example, if an Inform project says it wants to include
an extension which isn't anywhere to be seen, then the project itself is a
copy vertex, as are the Standard Rules extension, the CommandParserKit kit,
and such; the missing extension is represneted by a requirement vertex; and
the story file which the project would compile to, if only it could be
compiled, is a file vertex.

@e COPY_VERTEX from 1
@e FILE_VERTEX
@e REQUIREMENT_VERTEX

=
typedef struct build_vertex {
	int type; /* one of the |*_VERTEX| values above */
	struct linked_list *build_edges; /* of |build_vertex| */
	struct linked_list *use_edges; /* of |build_vertex| */

	struct inbuild_copy *buildable_if_copy;
	struct filename *buildable_if_internal_file;
	struct inbuild_requirement *findable;

	struct text_stream *annotation;
	struct source_file *read_as;
	int last_described_in_generation;

	int build_result;
	int last_built_in_generation;
	int always_build_this;
	struct build_script *script;
	MEMORY_MANAGEMENT
} build_vertex;

@h Creation.
First, the three colours of vertex.

=
build_vertex *Graphs::file_vertex(filename *F) {
	build_vertex *V = CREATE(build_vertex);
	V->type = FILE_VERTEX;
	V->buildable_if_copy = NULL;
	V->buildable_if_internal_file = F;
	V->build_edges = NEW_LINKED_LIST(build_vertex);
	V->use_edges = NEW_LINKED_LIST(build_vertex);
	V->script = BuildScripts::new();
	V->annotation = NULL;
	V->read_as = NULL;
	V->last_described_in_generation = 0;
	V->build_result = NOT_APPLICABLE;
	V->last_built_in_generation = -1;
	V->always_build_this = FALSE;
	return V;
}

build_vertex *Graphs::copy_vertex(inbuild_copy *C) {
	if (C == NULL) internal_error("no copy");
	if (C->vertex == NULL) {
		C->vertex = Graphs::file_vertex(NULL);
		C->vertex->type = COPY_VERTEX;
		C->vertex->buildable_if_copy = C;
	}
	return C->vertex;
}

build_vertex *Graphs::req_vertex(inbuild_requirement *R) {
	if (R == NULL) internal_error("no requirement");
	build_vertex *V = Graphs::file_vertex(NULL);
	V->type = REQUIREMENT_VERTEX;
	V->findable = R;
	return V;
}

@ Next, the two colours of edge. Note that between A and B there can be
at most one edge of each colour.

=
void Graphs::need_this_to_build(build_vertex *from, build_vertex *to) {
	if (from == NULL) internal_error("no from");
	if (to == NULL) internal_error("no to");
	if (from == to) internal_error("graph node depends on itself");
	build_vertex *V;
	LOOP_OVER_LINKED_LIST(V, build_vertex, from->build_edges)
		if (V == to) return;
	ADD_TO_LINKED_LIST(to, build_vertex, from->build_edges);
}

void Graphs::need_this_to_use(build_vertex *from, build_vertex *to) {
	if (from == NULL) internal_error("no from");
	if (to == NULL) internal_error("no to");
	if (from == to) internal_error("graph node depends on itself");
	build_vertex *V;
	LOOP_OVER_LINKED_LIST(V, build_vertex, from->use_edges)
		if (V == to) return;
	ADD_TO_LINKED_LIST(to, build_vertex, from->use_edges);
}

@ The script attached to a vertex is a list of instructions for how to build
the resource it refers to. Some vertices have no instructions provided, so:

=
int Graphs::can_be_built(build_vertex *V) {
	if (BuildScripts::script_length(V->script) > 0) return TRUE;
	return FALSE;
}

@h Writing.
This is a suitably indented printout of the graph as seen from a given
vertex: it's used by the Inbuild command |-graph|.

=
int no_desc_generations = 1;
void Graphs::describe(OUTPUT_STREAM, build_vertex *V, int recurse) {
	Graphs::describe_r(OUT, 0, V, recurse, NULL, NOT_APPLICABLE, no_desc_generations++);
}
void Graphs::describe_r(OUTPUT_STREAM, int depth, build_vertex *V,
	int recurse, pathname *stem, int following_build_edge, int description_round) {
	for (int i=0; i<depth; i++) WRITE("  ");
	if (following_build_edge == TRUE) WRITE("--build-> ");
	if (following_build_edge == FALSE) WRITE("--use---> ");
	Graphs::describe_vertex(OUT, V);
	WRITE(" ");
	TEMPORARY_TEXT(T);
	switch (V->type) {
		case COPY_VERTEX: Copies::write_copy(T, V->buildable_if_copy); break;
		case REQUIREMENT_VERTEX: Requirements::write(T, V->findable); break;
		case FILE_VERTEX: WRITE("%f", V->buildable_if_internal_file); break;
	}
	TEMPORARY_TEXT(S);
	WRITE_TO(S, "%p", stem);
	if (Str::prefix_eq(T, S, Str::len(S))) {
		WRITE("... "); Str::substr(OUT, Str::at(T, Str::len(S)), Str::end(T));
	} else {
		WRITE("%S", T);
	}
	DISCARD_TEXT(S);
	DISCARD_TEXT(T);
	if (V->last_described_in_generation == description_round) { WRITE(" q.v.\n"); return; }
	V->last_described_in_generation = description_round;
	WRITE("\n");
	if (recurse) {
		if (V->buildable_if_copy) stem = V->buildable_if_copy->location_if_path;
		if (V->buildable_if_internal_file)
			stem = Filenames::get_path_to(V->buildable_if_internal_file);
		build_vertex *W;
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->build_edges)
			Graphs::describe_r(OUT, depth+1, W, TRUE, stem, TRUE, description_round);
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->use_edges)
			Graphs::describe_r(OUT, depth+1, W, TRUE, stem, FALSE, description_round);
	}
}

void Graphs::describe_vertex(OUTPUT_STREAM, build_vertex *V) {
	if (V == NULL) WRITE("<none>");
	else switch (V->type) {
		case COPY_VERTEX: WRITE("[c%d]", V->allocation_id); break;
		case REQUIREMENT_VERTEX: WRITE("[r%d]", V->allocation_id); break;
		case FILE_VERTEX: WRITE("[f%d]", V->allocation_id); break;
	}
}

@ A similar but slightly different recursion for |-build-needs| and |-use-needs|.

=
void Graphs::show_needs(OUTPUT_STREAM, build_vertex *V, int uses_only) {
	Graphs::show_needs_r(OUT, V, 0, 0, uses_only);
}

void Graphs::show_needs_r(OUTPUT_STREAM, build_vertex *V,
	int depth, int true_depth, int uses_only) {
	if (V->type == COPY_VERTEX) {
		for (int i=0; i<depth; i++) WRITE("  ");
		inbuild_copy *C = V->buildable_if_copy;
		WRITE("%S: ", C->edition->work->genre->genre_name);
		Copies::write_copy(OUT, C); WRITE("\n");
		depth++;
	}
	if (V->type == REQUIREMENT_VERTEX) {
		for (int i=0; i<depth; i++) WRITE("  ");
		WRITE("missing %S: ", V->findable->work->genre->genre_name);
		Works::write(OUT, V->findable->work);
		if (VersionNumberRanges::is_any_range(V->findable->version_range) == FALSE) {
			WRITE(", need version in range ");
			VersionNumberRanges::write_range(OUT, V->findable->version_range);
		} else {
			WRITE(", any version will do");
		}
		WRITE("\n");
		depth++;
	}
	build_vertex *W;
	if (uses_only == FALSE)
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->build_edges)
			Graphs::show_needs_r(OUT, W, depth, true_depth+1, uses_only);
	if ((V->type == COPY_VERTEX) && ((true_depth > 0) || (uses_only))) {
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->use_edges)
			Graphs::show_needs_r(OUT, W, depth, true_depth+1, uses_only);
	}
}

@ And for |-build-missing| and |-use-missing|.

=
int Graphs::show_missing(OUTPUT_STREAM, build_vertex *V, int uses_only) {
	return Graphs::show_missing_r(OUT, V, 0, uses_only);
}

int Graphs::show_missing_r(OUTPUT_STREAM, build_vertex *V,
	int true_depth, int uses_only) {
	int N = 0;
	if (V->type == REQUIREMENT_VERTEX) {
		WRITE("missing %S: ", V->findable->work->genre->genre_name);
		Works::write(OUT, V->findable->work);
		if (VersionNumberRanges::is_any_range(V->findable->version_range) == FALSE) {
			WRITE(", need version in range ");
			VersionNumberRanges::write_range(OUT, V->findable->version_range);
		} else {
			WRITE(", any version will do");
		}
		WRITE("\n");
		N = 1;
	}
	build_vertex *W;
	if (uses_only == FALSE)
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->build_edges)
			N += Graphs::show_missing_r(OUT, W, true_depth+1, uses_only);
	if ((V->type == COPY_VERTEX) && ((true_depth > 0) || (uses_only))) {
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->use_edges)
			N += Graphs::show_missing_r(OUT, W, true_depth+1, uses_only);
	}
	return N;
}

@h Archiving.
This isn't simply a matter of printing out, of course, but very similar code
handles |-archive| and |-archive-to N|.

Note that the English language definition, which lives in the internal nest,
cannot be read from any other nest -- so we won't archive it.

=
void Graphs::archive(OUTPUT_STREAM, build_vertex *V, inbuild_nest *N,
	build_methodology *BM) {
	Graphs::archive_r(OUT, V, 0, N, BM);
}

void Graphs::archive_r(OUTPUT_STREAM, build_vertex *V, int true_depth, inbuild_nest *N,
	build_methodology *BM) {
	if (V->type == COPY_VERTEX) {
		inbuild_copy *C = V->buildable_if_copy;
		if ((Genres::stored_in_nests(C->edition->work->genre)) &&
			((Str::ne(C->edition->work->title, I"English")) ||
				(Str::len(C->edition->work->author_name) > 0)))
			@<Archive a single copy@>;
	}
	build_vertex *W;
	LOOP_OVER_LINKED_LIST(W, build_vertex, V->build_edges)
		Graphs::archive_r(OUT, W, true_depth+1, N, BM);
	if ((V->type == COPY_VERTEX) && (true_depth > 0)) {
		LOOP_OVER_LINKED_LIST(W, build_vertex, V->use_edges)
			Graphs::archive_r(OUT, W, true_depth+1, N, BM);
	}
}

@ The most delicate thing here is that we don't want to archive something
to |N| if it's already there; but that is difficult to detect.

@<Archive a single copy@> =
	WRITE("%S: ", C->edition->work->genre->genre_name);
	Copies::write_copy(OUT, C);

	pathname *P = C->location_if_path;
	if (C->location_if_file) P = Filenames::get_path_to(C->location_if_file);
	TEMPORARY_TEXT(nl);
	TEMPORARY_TEXT(cl);
	WRITE_TO(nl, "%p/", N->location);
	WRITE_TO(cl, "%p/", P);
	if (Str::prefix_eq(cl, nl, Str::len(nl))) {
		WRITE(" -- already there\n");
	} else {
		WRITE(" -- archiving\n");
		Copies::copy_to(C, N, TRUE, BM);
	}
	DISCARD_TEXT(nl);
	DISCARD_TEXT(cl);
