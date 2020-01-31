[Main::] Main.

The top level, which decides what is to be done and then carries
this plan out.

@h Main routine.

@d INTOOL_NAME "inbuild"

@e INSPECT_TTASK from 1
@e GRAPH_TTASK
@e BUILD_TTASK
@e REBUILD_TTASK

=
pathname *path_to_inbuild = NULL;
pathname *path_to_tools = NULL;
linked_list *nest_list = NULL;
linked_list *find_list = NULL;

int inbuild_task = INSPECT_TTASK;
int dry_run_mode = FALSE;
linked_list *targets = NULL; /* of |inbuild_copy| */

int main(int argc, char **argv) {
	Foundation::start();
	InbuildModule::start();
	targets = NEW_LINKED_LIST(inbuild_copy);
	nest_list = NEW_LINKED_LIST(inbuild_nest);
	find_list = NEW_LINKED_LIST(text_stream);
	@<Read the command line@>;
	if (FIRST_IN_LINKED_LIST(inbuild_nest, nest_list) == NULL)
		Nests::add_to_search_sequence(nest_list,
			Nests::new(Pathnames::from_text(I"inform7/Internal")));
	path_to_inbuild = Pathnames::installation_path("INBUILD_PATH", I"inbuild");
	build_methodology *BM;
	if (path_to_tools) BM = BuildSteps::methodology(path_to_tools, FALSE);
	else BM = BuildSteps::methodology(Pathnames::up(path_to_inbuild), TRUE);
	if (dry_run_mode == FALSE) BM->methodology = SHELL_METHODOLOGY;
	text_stream *T;
	LOOP_OVER_LINKED_LIST(T, text_stream, find_list) {
		linked_list *L = NEW_LINKED_LIST(inbuild_search_result);
		inbuild_work *work = Model::work(kit_genre, T, I""); 
		inbuild_requirement *req = Model::requirement(work,
			VersionNumbers::null(), VersionNumbers::null());
		Nests::locate(req, nest_list, L);
		int n = 0;
		inbuild_search_result *R;
		LOOP_OVER_LINKED_LIST(R, inbuild_search_result, L) {
			Model::write_copy(STDOUT, R->copy);
			WRITE_TO(STDOUT, " (in nest %p)\n", R->nest->location);
			n++;
		}
		if (n == 0) WRITE_TO(STDOUT, "%S not found\n", T);
	}
	inbuild_copy *C;
	LOOP_OVER_LINKED_LIST(C, inbuild_copy, targets) {
		switch (inbuild_task) {
			case INSPECT_TTASK: Graphs::describe(STDOUT, C->graph, FALSE); break;
			case GRAPH_TTASK: Graphs::describe(STDOUT, C->graph, TRUE); break;
			case BUILD_TTASK: Graphs::build(C->graph, BM); break;
			case REBUILD_TTASK: Graphs::rebuild(C->graph, BM); break;
		}
	}
	InbuildModule::end();
	Foundation::end();
	return 0;
}

@ We use Foundation to read the command line:

@e BUILD_CLSW
@e REBUILD_CLSW
@e GRAPH_CLSW
@e INSPECT_CLSW
@e DRY_CLSW
@e TOOLS_CLSW
@e CONTENTS_OF_CLSW
@e NEST_CLSW
@e FIND_CLSW

@<Read the command line@> =	
	CommandLine::declare_heading(
		L"[[Purpose]]\n\n"
		L"usage: inbuild [-TASK] TARGET1 TARGET2 ...\n");
	CommandLine::declare_switch(BUILD_CLSW, L"build", 1,
		L"incrementally build target(s)");
	CommandLine::declare_switch(REBUILD_CLSW, L"rebuild", 1,
		L"completely rebuild target(s)");
	CommandLine::declare_switch(INSPECT_CLSW, L"inspect", 1,
		L"show target(s) but take no action");
	CommandLine::declare_switch(GRAPH_CLSW, L"graph", 1,
		L"show dependency graph of target(s) but take no action");
	CommandLine::declare_switch(TOOLS_CLSW, L"tools", 2,
		L"make X the directory of intools executables, and exit developer mode");
	CommandLine::declare_boolean_switch(DRY_CLSW, L"dry", 1,
		L"make this a dry run (print but do not execute shell commands)");
	CommandLine::declare_boolean_switch(CONTENTS_OF_CLSW, L"contents-of", 2,
		L"apply to all targets in the directory X");
	CommandLine::declare_switch(NEST_CLSW, L"nest", 2,
		L"add the nest at pathname X to the search list");
	CommandLine::declare_switch(FIND_CLSW, L"find", 2,
		L"find copies in nests in the search list");

	CommandLine::read(argc, argv, NULL, &Main::option, &Main::bareword);

@ =
void Main::option(int id, int val, text_stream *arg, void *state) {
	switch (id) {
		case BUILD_CLSW: inbuild_task = BUILD_TTASK; break;
		case REBUILD_CLSW: inbuild_task = REBUILD_TTASK; break;
		case INSPECT_CLSW: inbuild_task = INSPECT_TTASK; break;
		case GRAPH_CLSW: inbuild_task = GRAPH_TTASK; break;
		case TOOLS_CLSW: path_to_tools = Pathnames::from_text(arg); break;
		case CONTENTS_OF_CLSW: Main::load_many(Pathnames::from_text(arg)); break;
		case DRY_CLSW: dry_run_mode = val; break;
		case NEST_CLSW: Nests::add_to_search_sequence(nest_list,
			Nests::new(Pathnames::from_text(arg))); break;
		case FIND_CLSW: ADD_TO_LINKED_LIST(Str::duplicate(arg), text_stream, find_list); break;
		default: internal_error("unimplemented switch");
	}
}

void Main::bareword(int id, text_stream *arg, void *state) {
	Main::load_one(arg);
}

void Main::load_many(pathname *P) {
	scan_directory *D = Directories::open(P);
	TEMPORARY_TEXT(LEAFNAME);
	while (Directories::next(D, LEAFNAME)) {
		TEMPORARY_TEXT(FILENAME);
		WRITE_TO(FILENAME, "%p%c%S", P, FOLDER_SEPARATOR, LEAFNAME);
		Main::load_one(FILENAME);
		DISCARD_TEXT(FILENAME);
	}
	DISCARD_TEXT(LEAFNAME);
	Directories::close(D);
}

void Main::load_one(text_stream *arg) {
	int pos = Str::len(arg) - 1, dotpos = -1;
	while (pos >= 0) {
		wchar_t c = Str::get_at(arg, pos);
		if (c == FOLDER_SEPARATOR) break;
		if (c == '.') dotpos = pos;
		pos--;
	}
	if (dotpos >= 0) {
		TEMPORARY_TEXT(extension);
		Str::substr(extension, Str::at(arg, dotpos+1), Str::end(arg));
		if (Str::eq(extension, I"i7x")) {
			;
		}
		DISCARD_TEXT(extension);
		return;
	}
	if (Str::get_last_char(arg) == FOLDER_SEPARATOR)
		Str::delete_last_character(arg);
	int kitpos = Str::len(arg) - 3;
	if ((kitpos >= 0) && (Str::get_at(arg, kitpos) == 'K') &&
		(Str::get_at(arg, kitpos+1) == 'i') &&
		(Str::get_at(arg, kitpos+2) == 't')) {
		pathname *P = Pathnames::from_text(arg);
		inform_kit *K = Kits::load_at(Pathnames::directory_name(P), P);
		ADD_TO_LINKED_LIST(K->as_copy, inbuild_copy, targets);
	}
}
