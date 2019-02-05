[Identifiers::] Identifiers.

To represent snippets of natural language in identifier form, which
a typical C-like compiler would accept.

@h Validity of identifiers.
In code compiled by I7, a valid identifier is a sequence of 1 to 31 characters,
which must be alphanumeric or else underscores, except that the leading
character must not be a 0:

=
int Identifiers::valid(wchar_t *p) {
	if ((Wide::len(p) == 0) || (Wide::len(p) > 31)) return FALSE;
	for (int i=0; p[i]; i++)
		if ((Characters::isdigit(p[i]) == 0) && (Characters::isalpha(p[i]) == 0) && (p[i] != '_'))
			return FALSE;
	if (Characters::isdigit(p[0])) return FALSE;
	return TRUE;
}

@h Automatically composed identifiers.
For the sake of legibility of the compiled code, we adapt natural language
descriptions to this format as best we can, in a standardised pattern which
uses an identifying letter (e.g., A for Action), a unique ID number
(preventing name-clashes) and then a truncated alphanumeric-safe form of
the words used in the textual description, if any. For example, an object
called "apple crumble" might have identifier |O100_apple_crumble|. Any
other object also called "apple crumble" would have a different identifier
since the number parts would be different.

Beginning with the identifying letter ensures that we do not open with
a 0 digit.

We truncate to 28 characters in length so that other routines can
concatenate our identifier with up to 3 further characters, if they choose.

=
void Identifiers::compose(text_stream *identifier, int nature_character, int id_number, wording W) {
	Str::clear(identifier);
	WRITE_TO(identifier, "%c%d", nature_character, id_number);
	if (Wordings::nonempty(W)) {
		LOOP_THROUGH_WORDING(j, W) {
			/* identifier is at this point 32 chars or fewer in length: add at most 30 more */
			if (Wide::len(Lexer::word_text(j)) > 30)
				WRITE_TO(identifier, " etc");
			else WRITE_TO(identifier, " %N", j);
			if (Str::len(identifier) > 32) break;
		}
	}
	Str::truncate(identifier, 28); /* it was at worst 62 chars in size, but is now truncated to 28 */
	Identifiers::purify(identifier);
}

void Identifiers::compose_numberless(text_stream *identifier, text_stream *prefix, wording W) {
	Str::copy(identifier, prefix);
	if (Wordings::nonempty(W)) {
		LOOP_THROUGH_WORDING(j, W) {
			/* identifier is at this point 32 chars or fewer in length: add at most 30 more */
			if (Wide::len(Lexer::word_text(j)) > 30)
				WRITE_TO(identifier, " etc");
			else WRITE_TO(identifier, " %N", j);
			if (Str::len(identifier) > 32) break;
		}
	}
	Str::truncate(identifier, 28); /* it was at worst 62 chars in size, but is now truncated to 28 */
	Identifiers::purify(identifier);
}

@ Where we flatten the characters into shape thus:

=
void Identifiers::purify(text_stream *identifier) {
	LOOP_THROUGH_TEXT(pos, identifier) {
		int x = Str::get(pos);
		if (!(((x >= '0') && (x <= '9')) ||
			((x >= 'a') && (x <= 'z')) || ((x >= 'A') && (x <= 'Z')) || (x == '_')))
			Str::put(pos, '_');
	}
}
