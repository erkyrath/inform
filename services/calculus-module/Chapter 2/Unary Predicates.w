[UnaryPredicates::] Unary Predicates.

A lightweight structure to record uses of an adjective, either
positively or negatively.

@ We store this as a linguistic constant, which points to the adjective and
also records its sense, i.e., positive or negative:

=
typedef struct unary_predicate {
	struct up_family *family;
	struct kind *assert_kind;
	lcon_ti lcon;
} unary_predicate;

@ =
unary_predicate *UnaryPredicates::blank(up_family *f) {
	unary_predicate *au = CREATE(unary_predicate);
	au->family = f;
	au->assert_kind = NULL;
	au->lcon = 0;
	return au;
}

unary_predicate *UnaryPredicates::copy(unary_predicate *au_from) {
	unary_predicate *au = CREATE(unary_predicate);
	au->family = au_from->family;
	au->lcon = au_from->lcon;
	return au;
}

unary_predicate *UnaryPredicates::new(adjective *aph, int pos) {
	unary_predicate *au = UnaryPredicates::blank(adjectival_up_family);
	au->lcon = Stock::to_lcon(aph->in_stock);
	if (pos) au->lcon = Lcon::set_sense(au->lcon, POSITIVE_SENSE);
	else au->lcon = Lcon::set_sense(au->lcon, NEGATIVE_SENSE);
	return au;
}

@ Logging:

=
void UnaryPredicates::log(unary_predicate *au) {
	adjective *aph = UnaryPredicates::get_adj(au);
	if (Lcon::get_sense(au->lcon) == NEGATIVE_SENSE) LOG("~");
	wording W = Adjectives::get_nominative_singular(aph);
	LOG("<adj:%W>", W);
}

@ Access:

=
adjective *UnaryPredicates::get_adj(unary_predicate *au) {
	if (au == NULL) return NULL;
	return Adjectives::from_lcon(au->lcon);
}

int UnaryPredicates::get_parity(unary_predicate *au) {
	if (au == NULL) internal_error("null adjective tested for positivity");
	if (Lcon::get_sense(au->lcon) == NEGATIVE_SENSE) return FALSE;
	return TRUE;
}

@ And this is the only non-trivial thing one can do with an adjective use:
reverse its sense.

=
void UnaryPredicates::flip_parity(unary_predicate *au) {
	if (au == NULL) internal_error("null adjective flipped");
	if (Lcon::get_sense(au->lcon) == NEGATIVE_SENSE)
		au->lcon = Lcon::set_sense(au->lcon, POSITIVE_SENSE);
	else
		au->lcon = Lcon::set_sense(au->lcon, NEGATIVE_SENSE);
}
