[Editions::] Editions.

An edition is numbered version of a work.

@h Editions.
An "edition" of a work is a particular version numbered form of it. For
example, release 7 of Bronze by Emily Short would be an edition of Bronze.

=
typedef struct inbuild_edition {
	struct inbuild_work *work;
	struct semantic_version_number version;
	struct compatibility_specification *compatibility;
	MEMORY_MANAGEMENT
} inbuild_edition;

inbuild_edition *Editions::new(inbuild_work *work, semantic_version_number version) {
	inbuild_edition *edition = CREATE(inbuild_edition);
	edition->work = work;
	edition->version = version;
	edition->compatibility = Compatibility::all();
	return edition;
}

void Editions::write(OUTPUT_STREAM, inbuild_edition *E) {
	Works::write(OUT, E->work);
	semantic_version_number V = E->version;
	if (VersionNumbers::is_null(V) == FALSE) {
		WRITE(" v%v", &V);
	}
}

void Editions::write_canonical_leaf(OUTPUT_STREAM, inbuild_edition *E) {
	WRITE("%S", E->work->title);
	if (VersionNumbers::is_null(E->version) == FALSE) {
		TEMPORARY_TEXT(vn);
		WRITE_TO(vn, "-v%v", &(E->version));
		LOOP_THROUGH_TEXT(pos, vn)
			if (Str::get(pos) == '.')
				PUT('_');
			else
				PUT(Str::get(pos));
		DISCARD_TEXT(vn);
	}
}

void Editions::inspect(OUTPUT_STREAM, inbuild_edition *E) {
	Editions::write(OUT, E);
	if (Compatibility::universal(E->compatibility) == FALSE) {
		WRITE(" (");
		Compatibility::write(OUT, E->compatibility);
		WRITE(")");
	}
}
