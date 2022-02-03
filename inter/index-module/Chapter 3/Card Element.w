[CardElement::] Card Element.

To write the Library Card element (Cd) in the index.

@ The Library Card is part of the Contents index, and is intended as a
natural way to present bibliographic data to the user. In effect, it's a
simplified form of the iFiction record, without the XML overhead.

=
void CardElement::render(OUTPUT_STREAM, index_session *session) {
	inter_tree *I = Indexing::get_tree(session);
	inter_package *pack = InterPackage::from_URL(I, I"/main/completion/bibliographic");
	
	HTML_OPEN("p");
	IndexUtilities::anchor(OUT, I"LCARD");
	HTML::begin_html_table(OUT, "*bg_images/indexcard.png", FALSE, 0, 3, 3, 0, 0);
	CardElement::Library_Card_entry(OUT, "Story title", pack, I"^title", I"Untitled");
	CardElement::Library_Card_entry(OUT, "Story author", pack, I"^author", I"Anonymous");
	CardElement::Library_Card_entry(OUT, "Story headline", pack, I"^headline", I"An Interactive Fiction");
	CardElement::Library_Card_entry(OUT, "Story genre", pack, I"^genre", I"Fiction");
	int E = (int) Metadata::read_optional_numeric(pack, I"^episode");
	text_stream *series_name = Metadata::read_optional_textual(pack, I"^series");
	if (series_name) {
		TEMPORARY_TEXT(episode_text)
		WRITE_TO(episode_text, "%d of %S", E, series_name);
		CardElement::Library_Card_entry(OUT, "Episode", pack, NULL, episode_text);
		DISCARD_TEXT(episode_text)
	}
	CardElement::Library_Card_entry(OUT, "Release number", pack, I"^release", I"1");
	CardElement::Library_Card_entry(OUT, "Story creation year", pack, I"^year", I"(This year)");
	CardElement::Library_Card_entry(OUT, "Language of play", pack, I"^language", I"English");
	CardElement::Library_Card_entry(OUT, "IFID number", pack, I"^IFID", NULL);
	CardElement::Library_Card_entry(OUT, "Story description", pack, I"^description", I"None");
	HTML::end_html_table(OUT);
	HTML_CLOSE("p");
}

@ This uses:

=
void CardElement::Library_Card_entry(OUTPUT_STREAM, char *field, inter_package *pack,
	text_stream *key, text_stream *t) {
	text_stream *col = I"303030";
	if (Str::eq(key, I"^title")) col = I"803030";
	HTML::first_html_column_nowrap(OUT, 0, NULL);
	HTML::begin_colour(OUT, col);
	HTML_OPEN_WITH("span", "class=\"typewritten\"");
	WRITE("%s", field);
	HTML_CLOSE("span");
	HTML::end_colour(OUT);
	HTML::next_html_column(OUT, 0);
	HTML::begin_colour(OUT, col);
	HTML_OPEN_WITH("span", "class=\"typewritten\"");
	HTML_OPEN("b");
	CardElement::index_variable(OUT, pack, key, t);
	HTML_CLOSE("b");
	HTML_CLOSE("span");
	HTML::end_colour(OUT);
	HTML::end_html_row(OUT);
}

@ And both of those features use:

=
void CardElement::index_variable(OUTPUT_STREAM, inter_package *pack,
	text_stream *key, text_stream *t) {
	if (key) {
		if (Str::eq(key, I"^release")) {
			int R = (int) Metadata::read_optional_numeric(pack, key);
			if (R > 0) { WRITE("%d", R); return; }
		} else {
			text_stream *matter = Metadata::read_optional_textual(pack, key);
			if (matter) { WRITE("%S", matter); return; }
		}
	}
	WRITE("%S", t);
}
