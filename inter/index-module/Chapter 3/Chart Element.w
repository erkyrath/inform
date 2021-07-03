[ChartElement::] Chart Element.

To write the Chart element (Ch) in the index.

@

=
void ChartElement::render(OUTPUT_STREAM, localisation_dictionary *LD) {
	inter_tree *I = InterpretIndex::get_tree();
	tree_inventory *inv = Synoptic::inv(I);
	TreeLists::sort(inv->kind_nodes, Synoptic::module_order);
	TreeLists::sort(inv->instance_nodes, Synoptic::module_order);
	ChartElement::index_kinds(OUT, inv, 1);
	ChartElement::index_kinds(OUT, inv, 2);
}

@h Indexing the kinds.
The Kinds page of the index opens with a table summarising the hierarchy of
kinds, and then follows with details. This routine is called twice, once
with |pass| equal to 1, when it has to fill in the hierarchy of kinds listed
under "value" in the key chart at the top of the Kinds index; and then
again lower down, with |pass| equal to 2, when it gives more detail.

Not all of the built-in kinds are indexed on the Kinds page. The ones
omitted are of no help to end users, and would only clutter up the table
with misleading entries. Remaining kinds are grouped together in
"priority" order, a device to enable the quasinumerical kinds to stick
together, the enumerative ones, and so on. A lower priority number puts you
higher up, but kinds with priority 0 do not appear in the index at all.

@d LOWEST_INDEX_PRIORITY 100

=
void ChartElement::index_kinds(OUTPUT_STREAM, tree_inventory *inv, int pass) {
	int priority;
	if (pass == 1) {
		HTML_OPEN("p"); HTML_CLOSE("p");
		HTML::begin_wide_html_table(OUT);
		@<Add a dotty row to the chart of kinds@>;
		@<Add a titling row to the chart of kinds@>;
		@<Add a dotty row to the chart of kinds@>;
		@<Add the rubric below the chart of kinds@>;
	}

	for (priority = 1; priority <= LOWEST_INDEX_PRIORITY; priority++) {
		for (int i=0; i<TreeLists::len(inv->kind_nodes); i++) {
			inter_package *pack = Inter::Package::defined_by_frame(inv->kind_nodes->list[i].node);
			if ((Metadata::read_optional_numeric(pack, I"^is_base")) &&
				(Metadata::read_optional_numeric(pack, I"^is_subkind_of_object") == 0) &&
				(priority == (int) Metadata::read_optional_numeric(pack, I"^index_priority"))) {
				if ((priority == 8) || (Metadata::read_optional_numeric(pack, I"^is_definite"))) {
					switch (pass) {
						case 1: @<Write table row for this kind@>; break;
						case 2: {
							@<Write heading for the detailed index entry for this kind@>;
							HTML::open_indented_p(OUT, 1, "tight");
							@<Index kinds of kinds matched by this kind@>;
							@<Index explanatory text supplied for a kind@>;
							@<Index literal patterns which can specify this kind@>;
							@<Index possible values of an enumerated kind@>;
							HTML_CLOSE("p");
							break;
						}
					}
					if (Str::eq(Metadata::read_textual(pack, I"^printed_name"), I"object"))
						@<Recurse to index subkinds of object@>;
				}
			}
		}
		if ((priority == 1) || (priority == 6) || (priority == 7)) {
			if (pass == 1) {
				@<Add a dotty row to the chart of kinds@>;
				if (priority == 7) {
					@<Add a second titling row to the chart of kinds@>;
					@<Add a dotty row to the chart of kinds@>;
				}
			} else HTML_TAG("hr");
		}
	}

	if (pass == 1) {
		@<Add a dotty row to the chart of kinds@>;
		HTML::end_html_table(OUT);
	} else {
		@<Explain about covariance and contravariance@>;
	}
}

@<Recurse to index subkinds of object@> =
	ChartElement::index_subkinds(OUT, inv, pack, 2, pass);

@ An atypical row:

@<Add a titling row to the chart of kinds@> =
	HTML::first_html_column_nowrap(OUT, 0, "#e0e0e0");
	WRITE("<b>basic kinds</b>");
	ChartElement::index_kind_col_head(OUT, "default value", "default");
	ChartElement::index_kind_col_head(OUT, "repeat", "repeat");
	ChartElement::index_kind_col_head(OUT, "props", "props");
	ChartElement::index_kind_col_head(OUT, "under", "under");
	HTML::end_html_row(OUT);

@ And another:

@<Add a second titling row to the chart of kinds@> =
	HTML::first_html_column_nowrap(OUT, 0, "#e0e0e0");
	WRITE("<b>making new kinds from old</b>");
	ChartElement::index_kind_col_head(OUT, "default value", "default");
	ChartElement::index_kind_col_head(OUT, "", NULL);
	ChartElement::index_kind_col_head(OUT, "", NULL);
	ChartElement::index_kind_col_head(OUT, "", NULL);
	HTML::end_html_row(OUT);

@ A dotty row:

@<Add a dotty row to the chart of kinds@> =
	HTML_OPEN_WITH("tr", "bgcolor=\"#888\"");
	HTML_OPEN_WITH("td", "height=\"1\" colspan=\"5\" cellpadding=\"0\"");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");

@ And then a typical row:

@<Write table row for this kind@> =
	char *repeat = "cross", *props = "cross", *under = "cross";
	int shaded = FALSE;
	if (Metadata::read_optional_numeric(pack, I"^shaded_in_index")) shaded = TRUE;
	if (Metadata::read_optional_numeric(pack, I"^finite_domain")) repeat = "tick";
	if (Metadata::read_optional_numeric(pack, I"^has_properties")) props = "tick";
	if (Metadata::read_optional_numeric(pack, I"^understandable")) under = "tick";
	if (priority == 8) { repeat = NULL; props = NULL; under = NULL; }
	ChartElement::begin_chart_row(OUT);
	ChartElement::index_kind_name_cell(OUT, shaded, pack);
	ChartElement::end_chart_row(OUT, shaded, pack, repeat, props, under);

@ Note the named anchors here, which must match those linked from the titling
row.

@<Add the rubric below the chart of kinds@> =
	HTML_OPEN_WITH("tr", "style=\"display:none\" id=\"default\"");
	HTML_OPEN_WITH("td", "colspan=\"5\"");
	WRITE("The <b>default value</b> is used when we make something like "
		"a variable but don't tell Inform what its value is. For instance, if "
		"we write 'Zero hour is a time that varies', but don't tell Inform "
		"anything specific like 'Zero hour is 11:21 PM.', then Inform uses "
		"the value in the table above to decide what it will be. "
		"The same applies if we create a property (for instance, 'A person "
		"has a number called lucky number.'). Kinds of value not included "
		"in the table cannot be used in variables and properties.");
	HTML_TAG("hr");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML_OPEN_WITH("tr", "style=\"display:none\" id=\"repeat\"");
	HTML_OPEN_WITH("td", "colspan=\"5\"");
	WRITE("A tick for <b>repeat</b> means that it's possible to "
		"repeat through values of this kind. For instance, 'repeat with T "
		"running through times:' is allowed, but 'repeat with N running "
		"through numbers:' is not - there are too many numbers for this to "
		"make sense. A tick here also means it's possible to form lists such "
		"as 'list of rulebooks', or to count the 'number of scenes'.");
	HTML_TAG("hr");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML_OPEN_WITH("tr", "style=\"display:none\" id=\"props\"");
	HTML_OPEN_WITH("td", "colspan=\"5\"");
	WRITE("A tick for <b>props</b> means that values of this "
		"kind can have properties. For instance, 'A scene can be thrilling or "
		"dull.' makes an either/or property of a scene, but 'A number can be "
		"nice or nasty.' is not allowed because it would cost too much storage "
		"space. (Of course 'Definition:' can always be used to make adjectives "
		"applying to numbers; it's only properties which have storage "
		"worries.)");
	HTML_TAG("hr");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML_OPEN_WITH("tr", "style=\"display:none\" id=\"under\"");
	HTML_OPEN_WITH("td", "colspan=\"5\"");
	WRITE("A tick for <b>under</b> means that it's possible "
		"to understand values of this kind. For instance, 'Understand \"award "
		"[number]\" as awarding.' might be allowed, if awarding were an action "
		"applying to a number, but 'Understand \"run [rule]\" as rule-running.' "
		"is not allowed - there are so many rules with such long names that "
		"Inform doesn't add them to its vocabulary during play.");
	HTML_TAG("hr");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");

@ The detailed entry lower down the page begins with:

@<Write heading for the detailed index entry for this kind@> =
	HTML::open_indented_p(OUT, 1, "halftight");
	Index::anchor_numbered(OUT, i); /* ...the anchor to which the grey icon in the table led */
	WRITE("<b>"); ChartElement::index_kind(OUT, pack, FALSE, TRUE); WRITE("</b>");
	WRITE(" (<i>plural</i> "); ChartElement::index_kind(OUT, pack, TRUE, FALSE); WRITE(")");
	text_stream *doc_ref = Metadata::read_optional_textual(pack, I"^documentation");
	if (Str::len(doc_ref) > 0) Index::DocReferences::link(OUT, doc_ref); /* blue help icon, if any */
	HTML_CLOSE("p");
	text_stream *variance =  Metadata::read_optional_textual(pack, I"^variance");
	if (Str::len(variance) > 0) {
		HTML::open_indented_p(OUT, 1, "tight");
		WRITE("<i>%S&nbsp;", variance);
		HTML_OPEN_WITH("a", "href=#contra>");
		HTML_TAG_WITH("img", "border=0 src=inform:/doc_images/shelp.png");
		HTML_CLOSE("a");
		WRITE("</i>");
		HTML_CLOSE("p");
	}

@<Index literal patterns which can specify this kind@> =
	text_stream *notation = Metadata::read_optional_textual(pack, I"^notation");
	if (Str::len(notation) > 0) {
		WRITE("%S", notation);
		HTML_TAG("br");
	}

@<Index kinds of kinds matched by this kind@> =
	int f = FALSE;
	WRITE("<i>Matches:</i> ");
	inter_symbol *wanted = PackageTypes::get(inv->of_tree, I"_conformance");
	inter_tree_node *D = Inter::Packages::definition(pack);
	LOOP_THROUGH_INTER_CHILDREN(C, D) {
		if (C->W.data[ID_IFLD] == PACKAGE_IST) {
			inter_package *entry = Inter::Package::defined_by_frame(C);
			if (Inter::Packages::type(entry) == wanted) {
				inter_symbol *xref = Metadata::read_optional_symbol(entry, I"^conformed_to");
				inter_package *other = Inter::Packages::container(xref->definition);
				if (f) WRITE(", ");
				ChartElement::index_kind(OUT, other, FALSE, TRUE);
				f = TRUE;
			}
		}
	}
	HTML_TAG("br");

@<Index possible values of an enumerated kind@> =
	if (Str::ne(Metadata::read_textual(pack, I"^printed_name"), I"object"))
		if (Metadata::read_optional_numeric(pack, I"^instance_count") > 0)
			ChartElement::index_instances(OUT, inv, pack, 1);

@<Index explanatory text supplied for a kind@> =
	ChartElement::index_inferences(OUT, pack, FALSE);

@<Explain about covariance and contravariance@> =
	HTML_OPEN("p");
	HTML_TAG_WITH("a", "name=contra");
	HTML_OPEN_WITH("span", "class=\"smaller\"");
	WRITE("<b>Covariance</b> means that if K is a kind of L, then something "
		"you make from K can be used as the same thing made from L. For example, "
		"a list of doors can be used as a list of things, because 'list of K' is "
		"covariant. <b>Contravariance</b> means it works the other way round. "
		"For example, an activity on things can be used as an activity on doors, "
		"but not vice versa, because 'activity of K' is contravariant.");
	HTML_CLOSE("span");
	HTML_CLOSE("p");

@h Kind table construction.
First, here's the table cell for the heading at the top of a column: the
link is to the part of the rubric explaining what goes into the column.

=
void ChartElement::index_kind_col_head(OUTPUT_STREAM, char *name, char *anchor) {
	HTML::next_html_column_nowrap(OUT, 0);
	WRITE("<i>%s</i>&nbsp;", name);
	if (anchor) {
		HTML_OPEN_WITH("a", "href=\"#\" onClick=\"showBasic('%s');\"", anchor);
		HTML_TAG_WITH("img", "border=0 src=inform:/doc_images/shelp.png");
		HTML_CLOSE("a");
	}
}

@ Once we're past the heading row, each row is made in two parts: first this
is called --

=
int striper = FALSE;
void ChartElement::begin_chart_row(OUTPUT_STREAM) {
	char *col = NULL;
	if (striper) col = "#f0f0ff";
	striper = striper?FALSE:TRUE;
	HTML::first_html_column_nowrap(OUT, 0, col);
}

@ That leads us into the cell for the name of the kind. The following
routine is used for the kind rows, but not for the kinds-of-object
rows; the cell for those is filled in a different way in "Index
Physical World".

It's convenient to return the shadedness: a row is shaded if it's for
a kind which can have enumerated values but doesn't at the moment --
for instance, the sound effects row is shaded if there are none.

=
int ChartElement::index_kind_name_cell(OUTPUT_STREAM, int shaded, inter_package *pack) {
	if (shaded) HTML::begin_colour(OUT, I"808080");
	ChartElement::index_kind(OUT, pack, FALSE, TRUE);
	if (Metadata::read_optional_numeric(pack, I"^is_quasinumerical")) {
		WRITE("&nbsp;");
		HTML_OPEN_WITH("a", "href=\"Kinds.html?segment2\"");
		HTML_TAG_WITH("img", "border=0 src=inform:/doc_images/calc1.png");
		HTML_CLOSE("a");
	}
	text_stream *doc_ref = Metadata::read_optional_textual(pack, I"^documentation");
	if (Str::len(doc_ref) > 0) Index::DocReferences::link(OUT, doc_ref);
	int i = (int) Metadata::read_optional_numeric(pack, I"^instance_count");
	if (i >= 1) WRITE(" [%d]", i);
	Index::below_link_numbered(OUT, pack->allocation_id);
	if (shaded) HTML::end_colour(OUT);
	return shaded;
}

@ Finally we close the name cell, add the remaining cells, and close out the
whole row.

=
void ChartElement::end_chart_row(OUTPUT_STREAM, int shaded, inter_package *pack,
	char *tick1, char *tick2, char *tick3) {
	if (tick1) HTML::next_html_column(OUT, 0);
	else HTML::next_html_column_spanning(OUT, 0, 4);
	if (shaded) HTML::begin_colour(OUT, I"808080");
	WRITE("%S", Metadata::read_optional_textual(pack, I"^index_default"));
	if (shaded) HTML::end_colour(OUT);
	if (tick1) {
		HTML::next_html_column_centred(OUT, 0);
		if (tick1)
			HTML_TAG_WITH("img",
				"border=0 alt=\"%s\" src=inform:/doc_images/%s%s.png",
				tick1, shaded?"grey":"", tick1);
		HTML::next_html_column_centred(OUT, 0);
		if (tick2)
			HTML_TAG_WITH("img",
				"border=0 alt=\"%s\" src=inform:/doc_images/%s%s.png",
				tick2, shaded?"grey":"", tick2);
		HTML::next_html_column_centred(OUT, 0);
		if (tick3)
			HTML_TAG_WITH("img",
				"border=0 alt=\"%s\" src=inform:/doc_images/%s%s.png",
				tick3, shaded?"grey":"", tick3);
	}
	HTML::end_html_row(OUT);
}

@h Indexing kind names.

=
void ChartElement::index_kind(OUTPUT_STREAM, inter_package *pack, int plural, int with_links) {
	if (pack == NULL) return;
	text_stream *key = (plural)?I"^index_plural":I"^index_singular";
	WRITE("%S", Metadata::read_optional_textual(pack, key));
	if (with_links) {
		int at = (int) Metadata::read_optional_numeric(pack, I"^at");
		if (at > 0) Index::link(OUT, at);
	}
}

@

@d MAX_OBJECT_INDEX_DEPTH 10000

=
void ChartElement::index_subkinds(OUTPUT_STREAM, tree_inventory *inv, inter_package *pack, int depth, int pass) {
	for (int j=0; j<TreeLists::len(inv->kind_nodes); j++) {
		inter_package *inner_pack = Inter::Package::defined_by_frame(inv->kind_nodes->list[j].node);
		if ((Metadata::read_optional_numeric(inner_pack, I"^is_base")) &&
			(Metadata::read_optional_numeric(inner_pack, I"^is_subkind_of_object"))) {
			inter_symbol *super_weak = Metadata::read_optional_symbol(inner_pack, I"^superkind");
			if ((super_weak) && (Inter::Packages::container(super_weak->definition) == pack))
				ChartElement::index_object_kind(OUT, inv, inner_pack, depth, pass);
		}
	}
}

void ChartElement::index_object_kind(OUTPUT_STREAM, tree_inventory *inv, inter_package *pack, int depth, int pass) {
	if (depth == MAX_OBJECT_INDEX_DEPTH) internal_error("MAX_OBJECT_INDEX_DEPTH exceeded");
	inter_symbol *class_s = Metadata::read_optional_symbol(pack, I"^object_class");
	if (class_s == NULL) internal_error("no class for object kind");
	text_stream *anchor = class_s->symbol_name;

	int shaded = FALSE;
	@<Begin the object citation line@>;
	@<Index the name part of the object citation@>;
	@<Index the link icons part of the object citation@>;
	@<End the object citation line@>;
	if (pass == 2) @<Add a subsidiary paragraph of details about this object@>;
	ChartElement::index_subkinds(OUT, inv, pack, depth+1, pass);
}

@<Begin the object citation line@> =
	if (pass == 1) ChartElement::begin_chart_row(OUT);
	if (pass == 2) {
		HTML::open_indented_p(OUT, depth, "halftight");
		Index::anchor(OUT, anchor);
	}

@<End the object citation line@> =
	if (pass == 1) ChartElement::end_chart_row(OUT, shaded, pack, "tick", "tick", "tick");
	if (pass == 2) HTML_CLOSE("p");

@<Index the name part of the object citation@> =
	if (pass == 1) {
		int c = (int) Metadata::read_optional_numeric(pack, I"^instance_count");
		if ((c == 0) && (pass == 1)) shaded = TRUE;
		if (shaded) HTML::begin_colour(OUT, I"808080");
		@<Quote the name of the object being indexed@>;
		if (shaded) HTML::end_colour(OUT);
		if ((pass == 1) && (c > 0)) WRITE(" [%d]", c);
	} else {
		@<Quote the name of the object being indexed@>;
	}

@<Quote the name of the object being indexed@> =
	if (pass == 2) WRITE("<b>");
	ChartElement::index_kind(OUT, pack, FALSE, FALSE);
	if (pass == 2) WRITE("</b>");
	if (pass == 2) {
		WRITE(" (<i>plural</i> "); ChartElement::index_kind(OUT, pack, TRUE, FALSE);
		WRITE(")");
	}

@<Index the link icons part of the object citation@> =
	int at = (int) Metadata::read_optional_numeric(pack, I"^at");
	if (at > 0) Index::link(OUT, at);
	text_stream *doc_ref = Metadata::read_optional_textual(pack, I"^documentation");
	if (Str::len(doc_ref) > 0) Index::DocReferences::link(OUT, doc_ref);
	if (pass == 1) Index::below_link(OUT, anchor);

@<Add a subsidiary paragraph of details about this object@> =
	HTML::open_indented_p(OUT, depth, "tight");
	ChartElement::index_inferences(OUT, pack, TRUE);
	HTML_CLOSE("p");
	ChartElement::index_instances(OUT, inv, pack, depth);

@ =
int ii_xtras = 900000;

void ChartElement::index_instances(OUTPUT_STREAM, tree_inventory *inv, inter_package *pack, int depth) {
	HTML::open_indented_p(OUT, depth, "tight");
	int c = (int) Metadata::read_optional_numeric(pack, I"^instance_count");
	if (c >= 10) {
		int xtra = ii_xtras++;
		Index::extra_link(OUT, xtra);
		HTML::begin_colour(OUT, I"808080");
		WRITE("%d ", c);
		ChartElement::index_kind(OUT, pack, TRUE, FALSE);
		HTML::end_colour(OUT);
		HTML_CLOSE("p");
		Index::extra_div_open(OUT, xtra, depth+1, "e0e0e0");
		@<Itemise the instances@>;
		Index::extra_div_close(OUT, "e0e0e0");
	} else {
		@<Itemise the instances@>;
		HTML_CLOSE("p");
	}
}

@<Itemise the instances@> =
	c = 0;
	for (int i=0; i<TreeLists::len(inv->instance_nodes); i++) {
		inter_package *I_pack = Inter::Package::defined_by_frame(inv->instance_nodes->list[i].node);
		inter_symbol *strong_kind_ID = Metadata::read_optional_symbol(I_pack, I"^kind_xref");
		if ((strong_kind_ID) && (Inter::Packages::container(strong_kind_ID->definition) == pack)) {
			if (c > 0) WRITE(", "); c++;
			HTML::begin_colour(OUT, I"808080");
			WRITE("%S", Metadata::read_optional_textual(I_pack, I"^name"));
			HTML::end_colour(OUT);
			int at = (int) Metadata::read_optional_numeric(I_pack, I"^at");
			if (at > 0) Index::link(OUT, at);
		}
	}

@ =
void ChartElement::index_inferences(OUTPUT_STREAM, inter_package *pack, int brief) {
	text_stream *explanation = Metadata::read_optional_textual(pack, I"^specification");
	if (Str::len(explanation) > 0) {
		WRITE("%S", explanation);
		HTML_TAG("br");
	}
	text_stream *material = NULL;
	if (brief) material = Metadata::read_optional_textual(pack, I"^brief_inferences");
	else material = Metadata::read_optional_textual(pack, I"^inferences");
	WRITE("%S", material);
}
