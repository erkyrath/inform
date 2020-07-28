[Index::DocReferences::] Documentation References.

To enable index or results pages to link into documentation.

@h Definitions.

@ Documentation is arranged in a series of HTML pages identified by
section number 0, 1, 2, ..., and the index contains little blue help
icons which link into this. In order to give these links the correct
destinations, Inform needs to know which section number contains what:
but section numbering moves around a lot as the documentation is
written.

To avoid needlessly recompiling Inform when documentation changes, we
give certain sections aliases called "symbols" which are rather
more lasting than the section numbering. These are read in from a file
of cross-references generated by Indoc.

=
typedef struct documentation_ref {
	struct text_stream *doc_symbol; /* Reference is by this piece of text */
	int section; /* HTML page number */
	int used_already; /* Has this been used in a problem message already? */
	int usage_count; /* For statistical purposes */
	char *fragment_at; /* Pointer to HTML documentation fragment in memory */
	int fragment_length; /* Number of bytes of fragment */
	int sr_usage_count;
	int ext_usage_count;
	wchar_t *chapter_reference; /* Or |NULL| if no chapter name supplied */
	wchar_t *section_reference; /* Or |NULL| if no section name supplied */
	CLASS_DEFINITION
} documentation_ref;

@

@d DOCUMENTATION_REFERENCE_PROBLEMS_CALLBACK Index::DocReferences::show_xref_in_problem

=
void Index::DocReferences::show_xref_in_problem(text_stream *OUT, text_stream *sigil) {
	wchar_t *chap = NULL, *sec = NULL;
	wchar_t *leaf = Index::DocReferences::link_if_possible_once(
		sigil, &chap, &sec);
	if (leaf) {
		HTML::open_indented_p(OUT, 2, "tight");
		HTML_OPEN_WITH("a", "href=inform:/%w.html", leaf);
		HTML_TAG_WITH("img", "border=0 src=inform:/doc_images/help.png");
		HTML_CLOSE("a");
		WRITE("&nbsp;");
		if ((chap) && (sec)) {
			WRITE("<i>See the manual: %w &gt; %w</i>", chap, sec);
		} else {
			WRITE("<i>See the manual.</i>");
		}
		HTML_CLOSE("p");
	}
}

@ The blue query icons link to pages in the documentation, as described above.
Documentation references are used to match the documentation text against
the compiler so that each can be changed independently of the other.
First, here's the code to read the Indoc-generated cross-references. The
file is read on demand; in some runs, it won't be needed.

=
int xrefs_read = FALSE;
void Index::DocReferences::read_xrefs(void) {
	if (xrefs_read == FALSE) {
		xrefs_read = TRUE;
		TextFiles::read(
			Supervisor::file_from_installation(DOCUMENTATION_XREFS_IRES), TRUE,
			NULL, FALSE, Index::DocReferences::read_xrefs_helper, NULL, NULL);
	}
}

void Index::DocReferences::read_xrefs_helper(text_stream *line,
	text_file_position *tfp, void *unused_state) {
	WRITE_TO(line, "\n");
	wording W = Feeds::feed_text(line);
	if (Wordings::length(W) < 2) return;

	int from = -1;
	LOOP_THROUGH_WORDING(i, W) {
		if (Lexer::word(i) == UNDERSCORE_V) from = i+1;
	}
	if (from == -1) internal_error("malformed cross-references file");

	wchar_t *chap = NULL, *sect = NULL;
	if ((Wordings::last_wn(W) >= from+1) && (Vocabulary::test_flags(from+1, TEXT_MC))) {
		Word::dequote(from+1);
		chap = Lexer::word_text(from+1);
	}
	if ((Wordings::last_wn(W) >= from+2) && (Vocabulary::test_flags(from+2, TEXT_MC))) {
		Word::dequote(from+2);
		sect = Lexer::word_text(from+2);
	}

	LOOP_THROUGH_WORDING(i, W) {
		if (i == from) break;
		documentation_ref *dr = CREATE(documentation_ref);
		dr->doc_symbol = Str::new();
		WRITE_TO(dr->doc_symbol, "%+W", Wordings::one_word(i));
		dr->section = from;
		dr->used_already = FALSE;
		dr->usage_count = 0;
		dr->sr_usage_count = 0;
		dr->ext_usage_count = 0;
		dr->chapter_reference = chap;
		dr->section_reference = sect;
		dr->fragment_at = NULL;
		dr->fragment_length = 0;
	}
}

@ The following routine is used to verify that a given text is, or is not,
a valid documentation reference symbol. (For instance, we might look up
|kind_vehicle| to see if any section of documentation has been flagged
as giving information on vehicles.) If our speculative link symbol exists,
we return the leafname for this documentation page, without filename
extension (say |doc24|); if it does not exist, we return NULL.

=
int Index::DocReferences::validate_if_possible(text_stream *temp) {
	Index::DocReferences::read_xrefs();
	documentation_ref *dr;
	LOOP_OVER(dr, documentation_ref)
		if (Str::eq(dr->doc_symbol, temp))
			return TRUE;
	return FALSE;
}

@ And similarly, returning the page we link to:

=
wchar_t *Index::DocReferences::link_if_possible_once(text_stream *temp, wchar_t **chap, wchar_t **sec) {
	Index::DocReferences::read_xrefs();
	documentation_ref *dr;
	LOOP_OVER(dr, documentation_ref)
		if (Str::eq(dr->doc_symbol, temp)) {
			if (dr->used_already == FALSE) {
				wchar_t *leaf = Lexer::word_text(dr->section);
				*chap = dr->chapter_reference;
				*sec = dr->section_reference;
				LOOP_OVER(dr, documentation_ref)
					if (Wide::cmp(leaf, Lexer::word_text(dr->section)) == 0)
						dr->used_already = TRUE;
				return leaf;
			}
		}
	return NULL;
}

@ In the Standard Rules, a number of phrases (and other constructs) are
defined along with markers to sections in the documentation: here we parse
these markers, returning either the word number of the documentation symbol
in question, or $-1$ if there is none. Since this is used only with the
Standard Rules, which are in English, there's no point in translating it
to other natural languages.

=
<documentation-symbol-tail> ::=
	... ( <documentation-symbol> ) |    ==> { pass 1 }
	... -- <documentation-symbol> --	==> { pass 1 }

<documentation-symbol> ::=
	documented at ###					==> Wordings::first_wn(WR[1])

@ =
wording Index::DocReferences::position_of_symbol(wording *W) {
	if (<documentation-symbol-tail>(*W)) {
		*W = GET_RW(<documentation-symbol-tail>, 1);
		return Wordings::one_word(<<r>>);
	}
	return EMPTY_WORDING;
}

@ It's convenient to associate a usage count to each symbol, since every
built-in documented phrase has a symbol. Every time Inform successfully uses
such a phrase, it increments the usage count by calling the following:

=
void Index::DocReferences::doc_mark_used(text_stream *symb, int at_word) {
	if (Log::aspect_switched_on(PHRASE_USAGE_DA)) {
		Index::DocReferences::read_xrefs();
		documentation_ref *dr;
		LOOP_OVER(dr, documentation_ref) {
			if (Str::eq(dr->doc_symbol, symb)) {
				if (at_word >= 0) {
					source_file *pos = Lexer::file_of_origin(at_word);
					inform_extension *loc = Extensions::corresponding_to(pos);
					if (loc == NULL) dr->usage_count++;
					else if (Extensions::is_standard(loc)) dr->sr_usage_count++;
					else dr->ext_usage_count++;
				} else dr->sr_usage_count++;
				return;
			}
		}
		internal_error("unable to update usage count");
	}
}

@ The following dumps the result. This is not useful for a single run,
especially, but to be accumulated over a whole corpus of source texts, e.g.:
= (text as ConsoleText)
	$ intest/Tangled/intest --keep-log=USAGE -log=phrase-usage examples
=

=
void Index::DocReferences::log_statistics(void) {
	LOGIF(PHRASE_USAGE, "The following shows how often each built-in phrase was used:\n");
	Index::DocReferences::read_xrefs();
	documentation_ref *dr;
	LOOP_OVER(dr, documentation_ref)
		if (Str::begins_with_wide_string(dr->doc_symbol, L"ph"))
			LOGIF(PHRASE_USAGE, "USAGE: %S %d %d %d\n", dr->doc_symbol,
				dr->usage_count, dr->sr_usage_count, dr->ext_usage_count);
}

@ Finally, the blue "see relevant help page" icon links are placed by the
following routine.

=
void Index::DocReferences::link_to(OUTPUT_STREAM, text_stream *fn, int full) {
	documentation_ref *dr = Index::DocReferences::name_to_dr(fn);
	if (dr) {
		if (full >= 0) WRITE("&nbsp;"); else WRITE(" ");
		HTML_OPEN_WITH("a", "href=inform:/%N.html", dr->section);
		HTML_TAG_WITH("img", "border=0 src=inform:/doc_images/help.png");
		HTML_CLOSE("a");
		if ((full > 0) && (dr->chapter_reference) && (dr->section_reference)) {
			WRITE("&nbsp;%w. %w", dr->chapter_reference, dr->section_reference);
		}
	}
}

void Index::DocReferences::link(OUTPUT_STREAM, text_stream *fn) {
	Index::DocReferences::link_to_S(OUT, fn, FALSE);
}

void Index::DocReferences::fully_link(OUTPUT_STREAM, text_stream *fn) {
	Index::DocReferences::link_to_S(OUT, fn, TRUE);
}

void Index::DocReferences::link_to_S(OUTPUT_STREAM, text_stream *fn, int full) {
	documentation_ref *dr = Index::DocReferences::name_to_dr(fn);
	if (dr) {
		if (full >= 0) WRITE("&nbsp;"); else WRITE(" ");
		HTML_OPEN_WITH("a", "href=inform:/%N.html", dr->section);
		HTML_TAG_WITH("img", "border=0 src=inform:/doc_images/help.png");
		HTML_CLOSE("a");
		if ((full > 0) && (dr->chapter_reference) && (dr->section_reference)) {
			WRITE("&nbsp;%w. %w", dr->chapter_reference, dr->section_reference);
		}
	}
}

@h Fragments.
These are short pieces of documentation, which |indoc| has copied into a special
file so that we can paste them into the index at appropriate places. Note that
if the file can't be found, or contains nothing germane, we fail safe by doing
nothing at all -- not issuing any internal errors.

=
void Index::DocReferences::doc_fragment(OUTPUT_STREAM, text_stream *fn) {
	Index::DocReferences::doc_fragment_to(OUT, fn);
}

int fragments_loaded = FALSE;
void Index::DocReferences::doc_fragment_to(OUTPUT_STREAM, text_stream *fn) {
	if (fragments_loaded == FALSE) {
		@<Load in the documentation fragments file@>;
		fragments_loaded = TRUE;
	}
	documentation_ref *dr = Index::DocReferences::name_to_dr(fn);
	if ((dr) && (dr->fragment_at)) {
		char *p = dr->fragment_at;
		int i;
		for (i=0; i<dr->fragment_length; i++) PUT(p[i]);
	}
}

@

@d MAX_EXTENT_OF_FRAGMENTS 256*1024

@<Load in the documentation fragments file@> =
	FILE *FRAGMENTS = Filenames::fopen(
		Supervisor::file_from_installation(DOCUMENTATION_SNIPPETS_IRES), "r");
	if (FRAGMENTS) {
		char *p = Memory::malloc(MAX_EXTENT_OF_FRAGMENTS, DOC_FRAGMENT_MREASON);
		@<Scan the file into memory, translating from UTF-8@>;
		@<Work out where the documentation fragments occur@>;
		fclose(FRAGMENTS);
	}

@ We scan to one long C string:

@<Scan the file into memory, translating from UTF-8@> =
	int i = 0;
	p[0] = 0;
	while (TRUE) {
		int c = TextFiles::utf8_fgetc(FRAGMENTS, NULL, FALSE, NULL);
		if (c == EOF) break;
		if (c == 0xFEFF) continue; /* the Unicode BOM non-character */
		if (i == MAX_EXTENT_OF_FRAGMENTS) break;
		p[i++] = (char) c;
		p[i] = 0;
	}

@<Work out where the documentation fragments occur@> =
	int i = 0;
	documentation_ref *tracking = NULL;
	for (i=0; p[i]; i++) {
		if ((p[i] == '*') && (p[i+1] == '=')) {
			i += 2;
			TEMPORARY_TEXT(rn)
			int j;
			for (j=0; p[i+j]; j++) {
				if ((p[i+j] == '=') && (p[i+j+1] == '*')) {
					i = i+j+1;
					tracking = Index::DocReferences::name_to_dr(rn);
					if (tracking) tracking->fragment_at = p+i+1;
					break;
				} else {
					PUT_TO(rn, p[i+j]);
				}
			}
			DISCARD_TEXT(rn)
		} else if (tracking) tracking->fragment_length++;
	}

@ This is a slow search, of course, but the number of DRs is relatively low,
and we need to search fairly seldom:

=
documentation_ref *Index::DocReferences::name_to_dr(text_stream *fn) {
	Index::DocReferences::read_xrefs();
	documentation_ref *dr;
	LOOP_OVER(dr, documentation_ref)
		if (Str::eq(dr->doc_symbol, fn))
			return dr;
	@<Complain about a bad documentation reference@>;
	return NULL;
}

@ You and I could write a bad reference:

@<Complain about a bad documentation reference@> =
	if (problem_count == 0) {
		LOG("Bad ref was <%S>. Known references are:\n", fn);
		Index::DocReferences::read_xrefs();
		LOOP_OVER(dr, documentation_ref)
			LOG("%S = %+N\n", dr->doc_symbol, dr->section);
		internal_error("Bad index documentation reference");
	}
