[Inter::Version::] The Version Construct.

Defining the version construct.

@

@e VERSION_IST

=
void Inter::Version::define(void) {
	inter_construct *IC = Inter::Defn::create_construct(
		VERSION_IST,
		L"version (%d+)",
		I"version", I"versions");
	IC->usage_permissions = OUTSIDE_OF_PACKAGES;
	METHOD_ADD(IC, CONSTRUCT_READ_MTID, Inter::Version::read);
	METHOD_ADD(IC, CONSTRUCT_VERIFY_MTID, Inter::Version::verify);
	METHOD_ADD(IC, CONSTRUCT_WRITE_MTID, Inter::Version::write);
}

@

@d NUMBER_VERSION_IFLD 2

@d EXTENT_VERSION_IFR 3

=
void Inter::Version::read(inter_construct *IC, inter_reading_state *IRS, inter_line_parse *ilp, inter_error_location *eloc, inter_error_message **E) {
	*E = Inter::Defn::vet_level(IRS, VERSION_IST, ilp->indent_level, eloc);
	if (*E) return;

	if (ilp->no_annotations > 0) { *E = Inter::Errors::plain(I"__annotations are not allowed", eloc); return; }

	*E = Inter::Version::new(IRS, Str::atoi(ilp->mr.exp[0], 0), (inter_t) ilp->indent_level, eloc);
}

inter_error_message *Inter::Version::new(inter_reading_state *IRS, int V, inter_t level, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_1(IRS, VERSION_IST, (inter_t) V, eloc, level);
	inter_error_message *E = Inter::Defn::verify_construct(P); if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

void Inter::Version::verify(inter_construct *IC, inter_frame P, inter_error_message **E) {
	if (P.extent != EXTENT_VERSION_IFR) { *E = Inter::Frame::error(&P, I"extent wrong", NULL); return; }
	if (P.data[NUMBER_VERSION_IFLD] < 1) { *E = Inter::Frame::error(&P, I"version out of range", NULL); return; }
}

void Inter::Version::write(inter_construct *IC, OUTPUT_STREAM, inter_frame P, inter_error_message **E) {
	WRITE("version %d", P.data[NUMBER_VERSION_IFLD]);
}
