[Inter::Binary::] Inter in Binary Files.

To read or write inter between memory and binary files.

@h Reading and writing inter to binary.
The binary representation of Inter, saved out to a file, is portable and
complete in itself.

=
int trace_bin = FALSE;

void Inter::Binary::read(inter_tree *I, filename *F) {
	LOGIF(INTER_FILE_READ, "(Reading binary inter file %f)\n", F);
	long int max_offset = BinaryFiles::size(F);

	FILE *fh = BinaryFiles::open_for_reading(F);

	inter_error_location eloc = Inter::Errors::interb_location(F, 0);
	inter_bookmark at = Inter::Bookmarks::at_start_of_this_repository(I);

	inter_warehouse *warehouse = Inter::warehouse(I);

	inter_t *grid = NULL;
	inter_t grid_extent = 0;
	unsigned int X = 0;

	@<Read the shibboleth@>;
	@<Read the annotations@>;
	@<Read the resources@>;
	@<Read the symbol equations@>;
	@<Read the bytecode@>;
	if (grid) Memory::I7_array_free(grid, INTER_BYTECODE_MREASON, (int) grid_extent, sizeof(inter_t));

	BinaryFiles::close(fh);
}

@ Symmetrically:

=
void Inter::Binary::write(filename *F, inter_tree *I) {
	if (trace_bin) WRITE_TO(STDOUT, "Writing binary inter file %f\n", F);
	LOGIF(INTER_FILE_READ, "(Writing binary inter file %f)\n", F);
	FILE *fh = BinaryFiles::open_for_writing(F);
	inter_warehouse *warehouse = Inter::warehouse(I);

	@<Write the shibboleth@>;
	@<Write the annotations@>;
	@<Write the resources@>;
	@<Write the symbol equations@>;
	@<Write the bytecode@>;

	BinaryFiles::close(fh);
}

@ The header is four bytes with a special value (equivalent to the ASCII
for |intr|), then four zero bytes, so that we can tell this file from a
text file coincidentally opening with those letters.

@d INTER_SHIBBOLETH ((inter_t) 0x696E7472)

@<Read the shibboleth@> =
	if ((BinaryFiles::read_int32(fh, &X) == FALSE) ||
		((inter_t) X != INTER_SHIBBOLETH) ||
		(BinaryFiles::read_int32(fh, &X) == FALSE) ||
		((inter_t) X != 0)) Inter::Binary::read_error(&eloc, 0, I"not a binary inter file");

@<Write the shibboleth@> =
	BinaryFiles::write_int32(fh, (unsigned int) INTER_SHIBBOLETH);
	BinaryFiles::write_int32(fh, (unsigned int) 0);

@ Next we have to describe the possible range of annotations. We need these
now, because they will be referred to in the symbol definitions in the
resource block later on.

@<Read the annotations@> =
	inter_t ID = 0;
	while (BinaryFiles::read_int32(fh, &ID)) {
		if (ID == 0) break;
		TEMPORARY_TEXT(keyword);
		unsigned int L;
		if (BinaryFiles::read_int32(fh, &L) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		for (unsigned int i=0; i<L; i++) {
			unsigned int c;
			if (BinaryFiles::read_int32(fh, &c) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			PUT_TO(keyword, (int) c);
		}
		inter_annotation_form *IA = Inter::Defn::create_annotation(ID, keyword, FALSE);
		if (IA == NULL) Inter::Binary::read_error(&eloc, ftell(fh), I"conflicting annotation name");
		DISCARD_TEXT(keyword);
	}

@<Write the annotations@> =
	inter_annotation_form *IAF;
	LOOP_OVER(IAF, inter_annotation_form) {
		if (IAF->annotation_ID == INVALID_IANN) continue;
		BinaryFiles::write_int32(fh, IAF->annotation_ID);
		BinaryFiles::write_int32(fh, (unsigned int) Str::len(IAF->annotation_keyword));
		LOOP_THROUGH_TEXT(P, IAF->annotation_keyword)
			BinaryFiles::write_int32(fh, (unsigned int) Str::get(P));
	}
	BinaryFiles::write_int32(fh, 0);

@ There follows a block of resources, which is a list in which each entry opens
with a word identifying which resource number is meant; when this is zero,
that's the end of the list and therefore the block. (There is no resource 0.)

@<Read the resources@> =
	unsigned int count = 0;
	if (BinaryFiles::read_int32(fh, &count) == FALSE)
		Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	if (count > 0) {
		unsigned int grid_extent = 0;
		if (BinaryFiles::read_int32(fh, &grid_extent) == FALSE)
			Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		if (grid_extent == 0) {
			Inter::Binary::read_error(&eloc, ftell(fh), I"max zero");
			grid_extent = 1000;
		}
		grid = (inter_t *) Memory::I7_calloc((int) grid_extent, sizeof(inter_t), INTER_BYTECODE_MREASON);
		for (inter_t i=0; i<grid_extent; i++) grid[i] = 0;
		for (inter_t i=0; i<count; i++) {
			unsigned int from_N;
			if (BinaryFiles::read_int32(fh, &from_N)) {
				inter_t n;
				switch (i) {
					case 0: n = (inter_t) I->root_package->package_scope->n_index; break;
					case 1: n =  (inter_t) I->root_package->index_n; break;
					default: n = Inter::Warehouse::create_resource(warehouse); break;
				}
	if (trace_bin) WRITE_TO(STDOUT, "Reading resource %d <--- %d\n", n, from_N);
				if (from_N >= grid_extent) {
					from_N = grid_extent-1;
					Inter::Binary::read_error(&eloc, ftell(fh), I"max incorrect");
				}
				grid[from_N] = n;
			} else Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		}
		for (inter_t i=0; i<grid_extent; i++) {
	if (trace_bin) WRITE_TO(STDOUT, "%d ", grid[i]);
		}
	if (trace_bin) WRITE_TO(STDOUT, "\n");
		
		for (inter_t i=0; i<count; i++) {
			unsigned int from_N = 0;
			if (BinaryFiles::read_int32(fh, &from_N) == FALSE)
				Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			if ((from_N == 0) || (from_N >= grid_extent)) {
				Inter::Binary::read_error(&eloc, ftell(fh), I"from-N out of range");
				from_N = grid_extent - 1;
			}
			inter_t n = grid[from_N];
			inter_resource_holder *res = &(warehouse->stored_resources[n]);
			unsigned int X = NO_IRSRC;
			if (BinaryFiles::read_int32(fh, &X) == FALSE)
				Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	if (trace_bin) WRITE_TO(STDOUT, "Reading resource %d -> %d type %d\n", from_N, n, X);
			switch (X) {
				case STRING_IRSRC: @<Read a string resource@>; break;
				case SYMBOLS_TABLE_IRSRC: @<Read a symbols table resource@>; break;
				case FRAME_LIST_IRSRC: @<Read a frame list resource@>; break;
				case PACKAGE_IRSRC: @<Read a package resource@>; break;
			}
		}
	}

@<Write the resources@> =
	int max = -1, count = 0;
	for (int n = 1; n < warehouse->size; n++) {
		inter_package *owner = warehouse->stored_resources[n].owning_package;
		if ((owner) && (owner->stored_in != I)) continue;
		count++;
		if (n+1 > max) max = n+1;
	}
	BinaryFiles::write_int32(fh, (unsigned int) count);
	if (count >= 0) {
		BinaryFiles::write_int32(fh, (unsigned int) max);
		for (int n = 1; n < warehouse->size; n++) {
			inter_package *owner = warehouse->stored_resources[n].owning_package;
			if ((owner) && (owner->stored_in != I)) continue;
			BinaryFiles::write_int32(fh, (unsigned int) n);
		}
		for (int n = 1; n < warehouse->size; n++) {
			inter_package *owner = warehouse->stored_resources[n].owning_package;
			if ((owner) && (owner->stored_in != I)) continue;
	if (trace_bin) WRITE_TO(STDOUT, "Writing resource %d type %d owner %s\n", n, warehouse->stored_resources[n].irsrc,
		(owner)?"yes":"no");
			BinaryFiles::write_int32(fh, (unsigned int) n);
			inter_resource_holder *res = &(warehouse->stored_resources[n]);
			if (res->stored_text_stream) {
				BinaryFiles::write_int32(fh, STRING_IRSRC);
				@<Write a string resource@>;
			} else if (res->stored_symbols_table) {
				BinaryFiles::write_int32(fh, SYMBOLS_TABLE_IRSRC);
				@<Write a symbols table resource@>;
			} else if (res->stored_package) {
				BinaryFiles::write_int32(fh, PACKAGE_IRSRC);
				@<Write a package resource@>;
			} else {
				BinaryFiles::write_int32(fh, FRAME_LIST_IRSRC);
				@<Write a frame list resource@>;
			}
		}
	}

@<Read a string resource@> =
	res->stored_text_stream = Str::new();
	unsigned int L;
	if (BinaryFiles::read_int32(fh, &L) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	for (unsigned int i=0; i<L; i++) {
		unsigned int c;
		if (BinaryFiles::read_int32(fh, &c) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		PUT_TO(res->stored_text_stream, (int) c);
	}

@<Write a string resource@> =
	BinaryFiles::write_int32(fh, (unsigned int) Str::len(res->stored_text_stream));
	LOOP_THROUGH_TEXT(P, res->stored_text_stream)
		BinaryFiles::write_int32(fh, (unsigned int) Str::get(P));

@<Read a symbols table resource@> =
	if (res->stored_symbols_table == NULL) res->stored_symbols_table = Inter::SymbolsTables::new();
	while (BinaryFiles::read_int32(fh, &X)) {
		if (X == 0) break;
		unsigned int st;
		if (BinaryFiles::read_int32(fh, &st) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		unsigned int sc;
		if (BinaryFiles::read_int32(fh, &sc) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");

		unsigned int L;
		if (BinaryFiles::read_int32(fh, &L) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		TEMPORARY_TEXT(name);
		for (unsigned int i=0; i<L; i++) {
			unsigned int c;
			if (BinaryFiles::read_int32(fh, &c) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			PUT_TO(name, (int) c);
		}
		if (BinaryFiles::read_int32(fh, &L) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		TEMPORARY_TEXT(trans);
		for (unsigned int i=0; i<L; i++) {
			unsigned int c;
			if (BinaryFiles::read_int32(fh, &c) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			PUT_TO(trans, (int) c);
		}

		inter_symbol *S = Inter::SymbolsTables::symbol_from_name_creating_at_ID(res->stored_symbols_table, name, X);
		S->symbol_type = (int) st;
		S->symbol_scope = (int) sc;
		if (Str::len(trans) > 0) Inter::Symbols::set_translate(S, trans);

		if (BinaryFiles::read_int32(fh, &L) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		for (unsigned int i=0; i<L; i++) {
			if (i >= MAX_INTER_ANNOTATIONS_PER_SYMBOL) Inter::Binary::read_error(&eloc, ftell(fh), I"excessive annotation");
			unsigned int c1, c2;
			if (BinaryFiles::read_int32(fh, &c1) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			if (BinaryFiles::read_int32(fh, &c2) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			inter_annotation IA = Inter::Defn::annotation_from_bytecode(c1, c2);
			if (Inter::Defn::is_invalid(IA)) Inter::Binary::read_error(&eloc, ftell(fh), I"invalid annotation");
			Inter::Symbols::annotate(S, IA);
		}
		if (S->symbol_scope == LINK_ISYMS) {
			S->equated_name = Str::new();
			while (TRUE) {
				unsigned int c;
				if (BinaryFiles::read_int32(fh, &c) == FALSE)
					Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
				if (c == 0) break;
				PUT_TO(S->equated_name, (wchar_t) c);
			}
		}

		LOGIF(INTER_BINARY, "Read symbol $3\n", S);
		DISCARD_TEXT(name);
		DISCARD_TEXT(trans);
	}

@<Write a symbols table resource@> =
	inter_symbols_table *T = res->stored_symbols_table;
	if (T) {
		for (int i=0; i<T->size; i++) {
			inter_symbol *symb = T->symbol_array[i];
			if (symb) {
				BinaryFiles::write_int32(fh, symb->symbol_ID);
				BinaryFiles::write_int32(fh, (unsigned int) symb->symbol_type);
				BinaryFiles::write_int32(fh, (unsigned int) symb->symbol_scope);
				BinaryFiles::write_int32(fh, (unsigned int) Str::len(symb->symbol_name));
				LOOP_THROUGH_TEXT(P, symb->symbol_name)
					BinaryFiles::write_int32(fh, (unsigned int) Str::get(P));
				BinaryFiles::write_int32(fh, (unsigned int) Str::len(symb->translate_text));
				LOOP_THROUGH_TEXT(P, symb->translate_text)
					BinaryFiles::write_int32(fh, (unsigned int) Str::get(P));
				BinaryFiles::write_int32(fh, (unsigned int) symb->no_symbol_annotations);
				for (int i=0; i<symb->no_symbol_annotations; i++) {
					inter_t c1 = 0, c2 = 0;
					Inter::Defn::annotation_to_bytecode(symb->symbol_annotations[i], &c1, &c2);
					BinaryFiles::write_int32(fh, (unsigned int) c1);
					BinaryFiles::write_int32(fh, (unsigned int) c2);
				}
				if (symb->symbol_scope == LINK_ISYMS) {
					LOOP_THROUGH_TEXT(pos, symb->equated_name)
						BinaryFiles::write_int32(fh, (unsigned int) Str::get(pos));
					BinaryFiles::write_int32(fh, 0);
				}
			}
		}
	}
	BinaryFiles::write_int32(fh, 0);

@ And similarly for packages.

@<Read a package resource@> =
	unsigned int p;
	if (BinaryFiles::read_int32(fh, &p) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	unsigned int cl;
	if (BinaryFiles::read_int32(fh, &cl) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	unsigned int rl;
	if (BinaryFiles::read_int32(fh, &rl) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	unsigned int sc;
	if (BinaryFiles::read_int32(fh, &sc) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	unsigned int nid;
	if (BinaryFiles::read_int32(fh, &nid) == FALSE) Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	inter_package *parent = NULL;
	if (p != 0) parent = Inter::get_package(I, grid[p]);
	if (res->stored_package == NULL) {
		res->stored_package = Inter::Packages::new(I, n);
	}
	if (cl) Inter::Packages::make_codelike(res->stored_package);
	if (rl) Inter::Packages::make_rootlike(res->stored_package);
	if (sc != 0) {
		if (grid) sc = grid[sc];
		Inter::Packages::set_scope(res->stored_package, Inter::get_symbols_table(I, sc));
	}
	if (nid != 0) {
		inter_symbol *pack_name = Inter::SymbolsTables::symbol_from_id(parent?(Inter::Packages::scope(parent)):Inter::get_global_symbols(I), nid);
		if (pack_name)
			Inter::Packages::set_name(res->stored_package, pack_name);
		else
			Inter::Binary::read_error(&eloc, ftell(fh), I"unable to retrieve package name");
	}

@<Write a package resource@> =
	inter_package *P = res->stored_package;
	if (P) {
		inter_package *par = Inter::Packages::parent(P);
		if (par == NULL) BinaryFiles::write_int32(fh, 0);
		else BinaryFiles::write_int32(fh, (unsigned int) par->index_n);
		BinaryFiles::write_int32(fh, (unsigned int) Inter::Packages::is_codelike(P));
		BinaryFiles::write_int32(fh, (unsigned int) Inter::Packages::is_rootlike(P));
		BinaryFiles::write_int32(fh, (unsigned int) P->package_scope->n_index);
		if (P->package_name)
			BinaryFiles::write_int32(fh, (unsigned int) P->package_name->symbol_ID);
		else
			BinaryFiles::write_int32(fh, 0);
	}

@ We do nothing here, because frame lists are built new on reading. It's
enough that the slot exists for the eventual list to be stored in.

@<Read a frame list resource@> =
	if (res->stored_frame_list == NULL) res->stored_frame_list = Inter::new_frame_list();

@<Write a frame list resource@> =
	;

@<Read the symbol equations@> =
	while (BinaryFiles::read_int32(fh, &X)) {
		if (X == 0) break;
		if (grid) X = grid[X];
		inter_symbols_table *from_T = Inter::get_symbols_table(I, X);
		if (from_T == NULL) {
			WRITE_TO(STDERR, "It's %d\n", X);
			internal_error("no from_T");
		}
		unsigned int from_ID = 0;
		while (BinaryFiles::read_int32(fh, &from_ID)) {
			if (from_ID == 0) break;
			unsigned int to_T_id = 0;
			unsigned int to_ID = 0;
			if (BinaryFiles::read_int32(fh, &to_T_id) == FALSE)
				Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			if (grid) to_T_id = grid[to_T_id];
	if (trace_bin) WRITE_TO(STDOUT, "Read eqn %d -> %d\n", X, to_T_id);
			if (BinaryFiles::read_int32(fh, &to_ID) == FALSE)
				Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
			inter_symbols_table *to_T = Inter::get_symbols_table(I, to_T_id);
			if (from_T == NULL) internal_error("no to_T");
			inter_symbol *from_S = Inter::SymbolsTables::symbol_from_id(from_T, from_ID);
			if (from_S == NULL) internal_error("no from_S");
			inter_symbol *to_S = Inter::SymbolsTables::symbol_from_id(to_T, to_ID);
			if (to_S == NULL) internal_error("no to_S");
			Inter::SymbolsTables::equate(from_S, to_S);
		}
	}

@<Write the symbol equations@> =
	for (int n = 1; n < warehouse->size; n++) {
		inter_package *owner = warehouse->stored_resources[n].owning_package;
		if ((owner) && (owner->stored_in != I)) continue;
		inter_resource_holder *res = &(warehouse->stored_resources[n]);
		if (res->stored_symbols_table) {
			inter_symbols_table *from_T = res->stored_symbols_table;
			BinaryFiles::write_int32(fh, (unsigned int) n);
			for (int i=0; i<from_T->size; i++) {
				inter_symbol *symb = from_T->symbol_array[i];
				if ((symb) && (symb->equated_to)) {
					BinaryFiles::write_int32(fh, symb->symbol_ID);
					BinaryFiles::write_int32(fh, (unsigned int) symb->equated_to->owning_table->n_index);
	if (trace_bin) WRITE_TO(STDOUT, "Write eqn %d -> %d\n", n, symb->equated_to->owning_table->n_index);
					BinaryFiles::write_int32(fh, symb->equated_to->symbol_ID);
				}
			}
			BinaryFiles::write_int32(fh, 0);
		}
	}
	BinaryFiles::write_int32(fh, 0);

@<Read the bytecode@> =
	while (BinaryFiles::read_int32(fh, &X)) {
		eloc.error_offset = (size_t) ftell(fh) - PREFRAME_SIZE;
		int extent = (int) X;
		if ((extent < 2) || ((long int) extent >= max_offset)) Inter::Binary::read_error(&eloc, ftell(fh), I"overlarge line");
	if (trace_bin) WRITE_TO(STDOUT, "Reading bytecode, extent %d\n", extent);

		inter_package *owner = NULL;
		unsigned int PID = 0;
		if (BinaryFiles::read_int32(fh, &PID)) {
			if (grid) PID = grid[PID];
	if (trace_bin) WRITE_TO(STDOUT, "PID %d\n", PID);
			owner = Inter::Packages::from_PID(I, PID);
	if (trace_bin) WRITE_TO(STDOUT, "Owner has ID %d, table %d\n", owner->index_n, owner->package_scope->n_index);

		}
		inter_frame P = Inter::Warehouse::find_room(warehouse, Inter::get_global_symbols(I), extent-1, &eloc, owner);

		for (int i=0; i<extent-1; i++) {
			unsigned int word = 0;
			if (BinaryFiles::read_int32(fh, &word)) P.data[i] = word;
			else Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
		}
		unsigned int comment = 0;
		if (BinaryFiles::read_int32(fh, &comment)) {
			if (comment != 0) Inter::Frame::attach_comment(P, (inter_t) comment);
		} else Inter::Binary::read_error(&eloc, ftell(fh), I"bytecode incomplete");
	if (trace_bin) WRITE_TO(STDOUT, "Verify\n");
		inter_error_message *E = NULL;
		if (grid) E = Inter::Defn::transpose_construct(owner, P, grid, grid_extent);
		if (E) { Inter::Errors::issue(E); exit(1); }
		E = Inter::Defn::verify_construct(owner, P);
		if (E) { Inter::Errors::issue(E); exit(1); }
	if (trace_bin) WRITE_TO(STDOUT, "Done\n");
		Inter::Frame::insert(P, &at);
	}

@<Write the bytecode@> =
	Inter::traverse_global_list(I, Inter::Binary::visitor, fh, -PACKAGE_IST);
	Inter::traverse_tree(I, Inter::Binary::visitor, fh, NULL, 0);

@ =
void Inter::Binary::visitor(inter_tree *I, inter_frame P, void *state) {
	FILE *fh = (FILE *) state;
	BinaryFiles::write_int32(fh, (unsigned int) (P.extent + 1));
	BinaryFiles::write_int32(fh, (unsigned int) (Inter::Frame::get_package(P)));
	for (int i=0; i<P.extent; i++)
		BinaryFiles::write_int32(fh, (unsigned int) (P.data[i]));
	BinaryFiles::write_int32(fh, (unsigned int) (Inter::Frame::get_comment(P)));
	LOGIF(INTER_BINARY, "Wrote %F\n", &P);
}

@ Errors in reading binary inter are not recoverable:

=
void Inter::Binary::read_error(inter_error_location *eloc, long at, text_stream *err) {
	eloc->error_offset = (size_t) at;
	Inter::Errors::issue(Inter::Errors::plain(err, eloc));
	exit(1);
}

@ This tests a file to see if it looks like Inter binary:

=
int Inter::Binary::test_file(filename *F) {
	int verdict = TRUE;
	FILE *fh = BinaryFiles::open_for_reading(F);
	unsigned int X = 0;
	if ((BinaryFiles::read_int32(fh, &X) == FALSE) ||
		((inter_t) X != INTER_SHIBBOLETH)) verdict = FALSE;
	if ((BinaryFiles::read_int32(fh, &X) == FALSE) ||
		((inter_t) X != 0)) verdict = FALSE;
	BinaryFiles::close(fh);
	return verdict;
}
