[ProjectBundleManager::] Project Bundle Manager.

A project bundle is a folder holding an Inform 7 work. The app creates these.

@h Genre definition.

=
inbuild_genre *project_bundle_genre = NULL;
void ProjectBundleManager::start(void) {
	project_bundle_genre = Genres::new(I"projectbundle", FALSE);
	METHOD_ADD(project_bundle_genre, GENRE_WRITE_WORK_MTID, ProjectBundleManager::write_work);
	METHOD_ADD(project_bundle_genre, GENRE_CLAIM_AS_COPY_MTID, ProjectBundleManager::claim_as_copy);
	METHOD_ADD(project_bundle_genre, GENRE_SEARCH_NEST_FOR_MTID, ProjectBundleManager::search_nest_for);
	METHOD_ADD(project_bundle_genre, GENRE_COPY_TO_NEST_MTID, ProjectBundleManager::copy_to_nest);
	METHOD_ADD(project_bundle_genre, GENRE_GO_OPERATIONAL_MTID, ProjectBundleManager::go_operational);
	METHOD_ADD(project_bundle_genre, GENRE_READ_SOURCE_TEXT_FOR_MTID, ProjectBundleManager::read_source_text_for);
	METHOD_ADD(project_bundle_genre, GENRE_BUILDING_SOON_MTID, ProjectBundleManager::building_soon);
}

void ProjectBundleManager::write_work(inbuild_genre *gen, OUTPUT_STREAM, inbuild_work *work) {
	WRITE("%S", work->title);
}

@ Project copies are annotated with a structure called an |inform_project|,
which stores data about extensions used by the Inform compiler.

=
inform_project *ProjectBundleManager::from_copy(inbuild_copy *C) {
	if ((C) && (C->edition->work->genre == project_bundle_genre)) {
		return RETRIEVE_POINTER_inform_project(C->content);
	}
	return NULL;
}

inbuild_copy *ProjectBundleManager::new_copy(text_stream *name, pathname *P) {
	inform_project *K = Projects::new_ip(name, NULL, P);
	inbuild_work *work = Works::new(project_bundle_genre, Str::duplicate(name), NULL);
	inbuild_edition *edition = Editions::new(work, K->version);
	K->as_copy = Copies::new_in_path(edition, P);
	Copies::set_content(K->as_copy, STORE_POINTER_inform_project(K));
	return K->as_copy;
}

@h Claiming.
Here |arg| is a textual form of a filename or pathname, such as may have been
supplied at the command line; |ext| is a substring of it, and is its extension
(e.g., |jpg| if |arg| is |Geraniums.jpg|), or is empty if there isn't one;
|directory_status| is true if we know for some reason that this is a directory
not a file, false if we know the reverse, and otherwise not applicable.

A project needs to be a directory whose name ends in |.inform|.

=
void ProjectBundleManager::claim_as_copy(inbuild_genre *gen, inbuild_copy **C,
	text_stream *arg, text_stream *ext, int directory_status) {
	if (directory_status == FALSE) return;
	if (Str::eq_insensitive(ext, I"inform")) {
		pathname *P = Pathnames::from_text(arg);
		*C = ProjectBundleManager::claim_folder_as_copy(P);
	}
}

inbuild_copy *ProjectBundleManager::claim_folder_as_copy(pathname *P) {
	inbuild_copy *C = ProjectBundleManager::new_copy(Pathnames::directory_name(P), P);
	Works::add_to_database(C->edition->work, CLAIMED_WDBC);
	return C;
}

@h Searching.
Here we look through a nest to find all projects matching the supplied
requirements; though in fact... projects are not nesting birds.

=
void ProjectBundleManager::search_nest_for(inbuild_genre *gen, inbuild_nest *N,
	inbuild_requirement *req, linked_list *search_results) {
}

@h Copying.
Now the task is to copy a project into place in a nest; or would be, if only
projects lived there.

=
void ProjectBundleManager::copy_to_nest(inbuild_genre *gen, inbuild_copy *C, inbuild_nest *N,
	int syncing, build_methodology *meth) {
	Errors::with_text("projects (which is what '%S' is) cannot be copied to nests",
		C->edition->work->title);
}

@h Build graph.

=
void ProjectBundleManager::building_soon(inbuild_genre *gen, inbuild_copy *C, build_vertex **V) {
	inform_project *project = ProjectBundleManager::from_copy(C);
	*V = project->chosen_build_target;
}

void ProjectBundleManager::go_operational(inbuild_genre *G, inbuild_copy *C) {
	Projects::construct_graph(ProjectBundleManager::from_copy(C));
}

@h Source text.

=
void ProjectBundleManager::read_source_text_for(inbuild_genre *G, inbuild_copy *C) {
	Projects::read_source_text_for(ProjectBundleManager::from_copy(C));
}
