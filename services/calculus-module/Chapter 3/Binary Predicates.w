[BinaryPredicates::] Binary Predicates.

To create and manage binary predicates, which are the underlying
data structures beneath Inform's relations.

@ Given any binary predicate $B$, we may wish to do some or all of the
following at run-time:

(a) Test whether or not $B(x, y)$ is true at run-time. Here Inform
needs to compile an I6 condition.

(b) Assert that $B(x, y)$ is true in the assertion sentences of
the source text. Inform will need to remember all pairs $x, y$ for which $B$
has been asserted so that it can compile this information as the original
state of the I6 data structure containing the current state of $B$.

(c) Set $B(x, y)$ true, or false, at run-time. Here Inform needs to
compile I6 code which will modify that data structure.

Some BPs provide an I6 schema to achieve (a), others provide (a) and (b),
while a happy few provide all of (a), (b), (c).

The variety of BPs is such that different BPs use very different run-time
mechanisms. Some relations compile elaborate routines to test (a), some
look at parents or chidren in the I6 object tree, some look at I6 property
values, others look inside bitmaps. The actual work is often done by routines
in the I6 template, which are called by code generated by the I6 schema for
(a); and similarly for (b) and (c).

@ Each BP has a partner which we call its "reversal". If $B$ is the
original and $R$ is its reversal, then $B(x, y)$ is true if and only if
$R(y, x)$ is true. Reversals sometimes occur quite naturally in English
language. "To wear" is the reversal of "to be worn by". "Contains" is
the reversal of being "inside". (Though not every BP has an interesting
reversal. The reversal of "is" -- equality -- looks much the same as the
original, because $x=y$ if and only if $y=x$.)

The following sentences express the same fact:

>> The ball is inside the trophy case.
>> The trophy case contains the ball.

...but when we parse them into their meanings, we could easily lose sight
that they are saying the same thing, because they involve different BPs:
= (text)
	inside(ball, trophy case)| and |contains(trophy case, ball)
=
It's usually a bad idea for any computer program to represent the same
conceptual idea in more than one way. So for every pair of BPs $X$ and $Y$
which are each other's reversal, Inform designates one as being
"the right way round" and the other as being "the wrong way round".
Whenever a sentence's meaning involves a BP which is "the wrong way
round", Inform swaps over the terms and replaces the BP by its reversal,
which is "the right way round". That makes it much easier to recognise
when pairs of sentences like the one above are duplicating each other's
meanings.

This is purely an internal implementation trick. There's no natural sense
in language or mathematics in which "contains" is the right way round
and "inside" the wrong way round.

@ We can finally now declare the epic BP structure.

=
typedef struct binary_predicate {
	struct bp_family *relation_family;
	struct word_assemblage relation_name; /* (which might have length 0) */
	struct parse_node *bp_created_at; /* where declared in the source text */
	struct text_stream *debugging_log_name; /* used when printing propositions to the debug log */

	struct bp_term_details term_details[2]; /* term 0 is the left term, 1 is the right */

	struct binary_predicate *reversal; /* the $R$ such that $R(x,y)$ iff $B(y,x)$ */
	int right_way_round; /* was this BP created directly? or is it a reversal of another? */

	/* how to compile code which tests or forces this BP to be true or false: */
	struct i6_schema *task_functions[4]; /* I6 schema for tasks */

	/* for use in the A-parser: */
	int relates_values_not_objects; /* true if either term is necessarily a value... */
	TERM_DOMAIN_CALCULUS_TYPE *knowledge_about_bp; /* ...and if so, here's the list of known assertions */

	/* for optimisation of run-time code: */
	int dynamic_memory; /* stored in dynamically allocated memory */
	int allow_function_simplification; /* allow Inform to make use of any $f_i$ functions? */
	int fast_route_finding; /* use fast rather than slow route-finding algorithm? */
	char *loop_parent_optimisation_proviso; /* if not NULL, optimise loops using object tree */
	char *loop_parent_optimisation_ranger; /* if not NULL, routine iterating through contents */

	general_pointer family_specific; /* details for particular kinds of BP */

	#ifdef CORE_MODULE
	struct bp_runtime_implementation *imp;
	#endif

	CLASS_DEFINITION
} binary_predicate;

@ That completes the catalogue of the one-off cases, and we can move on
to the five families of implicit relations which correspond to other
structures in the source text.

@ The second family of implicit relations corresponds to any property which has
been given as the meaning of a verb, as in the example

>> The verb to weigh (it weighs, they weigh, it is weighing) implies the weight property.

This implicitly constructs a relation $W(p, w)$ where $p$ is a thing and
$w$ a weight.

@ The third family corresponds to defined adjectives which perform a
numerical comparison in a particular way, as here:

>> Definition: A woman is tall if her height is 68 or more.

This implicitly constructs a relation $T(x, y)$ which is true if and only
if woman $x$ is taller than woman $y$.

@ The fourth family corresponds to value properties, so that

>> A door has a number called street number.

implicitly constructs a relation $SN(d_1, d_2)$ which is true if and only if
doors $d_1$ and $d_2$ have the same street number.

@ The fifth family corresponds to names of table columns. If any table includes
a column headed "eggs per clutch" then that will implicitly construct a
relation $LEPC(n, T)$ which is true if and only if the number $n$ is listed
as one of the eggs-per-clutch entries in the table $T$, where $T$ has to be
one of the tables which has a column of this name.

@d VERB_MEANING_LINGUISTICS_TYPE struct binary_predicate
@d VERB_MEANING_REVERSAL_LINGUISTICS_CALLBACK BinaryPredicates::get_reversal
@d VERB_MEANING_EQUALITY R_equality
@d VERB_MEANING_POSSESSION a_has_b_predicate

@ Combining these:

=
kind *BinaryPredicates::kind(binary_predicate *bp) {
	if (bp == R_equality) return Kinds::binary_con(CON_relation, K_value, K_value);
	kind *K0 = BPTerms::kind(&(bp->term_details[0]));
	kind *K1 = BPTerms::kind(&(bp->term_details[1]));
	if (K0 == NULL) K0 = K_object;
	if (K1 == NULL) K1 = K_object;
	return Kinds::binary_con(CON_relation, K0, K1);
}

@ And as a convenience:

=
void BinaryPredicates::set_index_details(binary_predicate *bp, char *left, char *right) {
	if (left) {
		bp->term_details[0].index_term_as = left;
		bp->reversal->term_details[1].index_term_as = left;
	}
	if (right) {
		bp->term_details[1].index_term_as = right;
		bp->reversal->term_details[0].index_term_as = right;
	}
}

@h Making the equality relation.
As we shall see below, BPs are almost always created in matched pairs. There
is one and only one exception to this rule: the equality predicate where
$EQ(x, y)$ if $x = y$. Equality plays a special role in the system of logic
we'll be using. Since $x = y$ and $y = x$ are exactly equivalent, it is safe
to make $EQ$ its own reversal; this makes it impossible for equality to occur
"the wrong way round" in any proposition, even one which is not yet fully
simplified.

There is no fixed domain to which $x$ and $y$ belong: equality can be
used whenever $x$ and $y$ belong to the same domain. Thus "if the score is
12" and "if the location is the Pantheon" are both valid uses of $EQ$,
where $x$ and $y$ are numbers in the former case and rooms in the latter.
It will take special handling in the type-checker to achieve
this effect. For now, we give $EQ$ entirely blank term details.

=
binary_predicate *BinaryPredicates::make_equality(bp_family *family, word_assemblage WA) {
	binary_predicate *bp = BinaryPredicates::make_single(family,
		BPTerms::new(NULL), BPTerms::new(NULL),
		I"is", NULL, NULL, WA);
	bp->reversal = bp; bp->right_way_round = TRUE;
	#ifdef REGISTER_RELATIONS_CALCULUS_CALLBACK
	REGISTER_RELATIONS_CALCULUS_CALLBACK(bp, WA);
	#endif
	return bp;
}

@h Making a pair of relations.
Every other BP belongs to a matched pair, in which each is the reversal of
the other, but only one is designated as being "the right way round".
The left-hand term of one behaves like the right-hand term of the other,
and vice versa.

The BP which is the wrong way round is never used in compilation, because
it will long before that have been reversed, so we only fill in details of
how to compile the BP for the one which is the right way round.

=
binary_predicate *BinaryPredicates::make_pair(bp_family *family,
	bp_term_details left_term, bp_term_details right_term,
	text_stream *name, text_stream *namer,
	i6_schema *mtf, i6_schema *tf, word_assemblage source_name) {
	binary_predicate *bp, *bpr;
	TEMPORARY_TEXT(n)
	TEMPORARY_TEXT(nr)
	Str::copy(n, name);
	if (Str::len(n) == 0) WRITE_TO(n, "nameless");
	Str::copy(nr, namer);
	if (Str::len(nr) == 0) WRITE_TO(nr, "%S-r", n);

	bp  = BinaryPredicates::make_single(family, left_term, right_term, n,
		mtf, tf, source_name);
	bpr = BinaryPredicates::make_single(family, right_term, left_term, nr,
		NULL, NULL, WordAssemblages::lit_0());

	bp->reversal = bpr; bpr->reversal = bp;
	bp->right_way_round = TRUE; bpr->right_way_round = FALSE;

	if (WordAssemblages::nonempty(source_name)) {
		#ifdef REGISTER_RELATIONS_CALCULUS_CALLBACK
		REGISTER_RELATIONS_CALCULUS_CALLBACK(bp, source_name);
		#endif
	}

	return bp;
}

@h BP construction.
The following routine should only ever be called from the two above: provided
we stick to that, we ensure the golden rule that {\it every BP has a reversal
and a BP equals its reversal if and only if it is the equality relation}.

It looks a little asymmetric that the "make true function" schema |mtf| is an
argument here, but the "make false function" isn't. That's because it happens
that the implicit relations defined in this section of code generally do
support making-true, but don't support making-false, so that such an argument
would always be |NULL| in practice.

=
binary_predicate *BinaryPredicates::make_single(bp_family *family,
	bp_term_details left_term, bp_term_details right_term,
	text_stream *name,
	i6_schema *mtf, i6_schema *tf, word_assemblage rn) {
	binary_predicate *bp = CREATE(binary_predicate);
	bp->relation_family = family;
	bp->relation_name = rn;
	bp->bp_created_at = current_sentence;
	bp->debugging_log_name = Str::duplicate(name);

	bp->term_details[0] = left_term; bp->term_details[1] = right_term;

	/* the |reversal| and the |right_way_round| field must be set by the caller */

	/* for use in code compilation */
	bp->task_functions[TEST_ATOM_TASK] = tf;
	bp->task_functions[NOW_ATOM_TRUE_TASK] = mtf;
	bp->task_functions[NOW_ATOM_FALSE_TASK] = NULL;

	/* for use by the A-parser */
	bp->relates_values_not_objects = FALSE;
	#ifdef CORE_MODULE
	bp->knowledge_about_bp =
		InferenceSubjects::new(relations,
			RELN_SUB, STORE_POINTER_binary_predicate(bp), CERTAIN_CE);
	#endif
	#ifndef CORE_MODULE
	bp->knowledge_about_bp = NULL;
	#endif
	
	/* for optimisation of run-time code */
	bp->dynamic_memory = FALSE;
	bp->allow_function_simplification = TRUE;
	bp->fast_route_finding = FALSE;
	bp->loop_parent_optimisation_proviso = NULL;
	bp->loop_parent_optimisation_ranger = NULL;

	/* details for particular kinds of relation */
	bp->family_specific = NULL_GENERAL_POINTER;

	#ifdef CORE_MODULE
	bp->imp = RTRelations::implement(bp);
	#endif

	return bp;
}

@h The package.

=
#ifdef CORE_MODULE
#endif

@h BP and term logging.

=
void BinaryPredicates::log_term_details(bp_term_details *bptd, int i) {
	LOG("  function(%d): $i\n", i, bptd->function_of_other);
	if (Wordings::nonempty(bptd->called_name)) LOG("  term %d is '%W'\n", i, bptd->called_name);
	if (bptd->implies_infs) {
		wording W = TERM_DOMAIN_WORDING_FUNCTION(bptd->implies_infs);
		if (Wordings::nonempty(W)) LOG("  term %d has domain %W\n", i, W);
	}
}

void BinaryPredicates::log(binary_predicate *bp) {
	if (bp == NULL) { LOG("<null-BP>\n"); return; }
	#ifdef CORE_MODULE
	LOG("BP%d <%S> - %s way round - %s\n",
		bp->allocation_id, bp->debugging_log_name, bp->right_way_round?"right":"wrong",
		Relations::Explicit::form_to_text(bp));
	#endif
	#ifndef CORE_MODULE
	LOG("BP%d <%S> - %s way round\n",
		bp->allocation_id, bp->debugging_log_name, bp->right_way_round?"right":"wrong");
	#endif
	for (int i=0; i<2; i++) BinaryPredicates::log_term_details(&bp->term_details[i], i);
	LOG("  test: $i\n", bp->task_functions[TEST_ATOM_TASK]);
	LOG("  make true: $i\n", bp->task_functions[NOW_ATOM_TRUE_TASK]);
	LOG("  make false: $i\n", bp->task_functions[NOW_ATOM_FALSE_TASK]);
}

@h Relation names.
A useful little nonterminal to spot the names of relation, such as
"adjacency". (Note: not "adjacency relation".) This is only used when there
is good reason to suspect that the word in question is the name of a relation,
so the fact that it runs relatively slowly does not matter.

=
<relation-name> internal {
	binary_predicate *bp;
	LOOP_OVER(bp, binary_predicate)
		if (WordAssemblages::compare_with_wording(&(bp->relation_name), W)) {
			==> { -, bp }; return TRUE;
		}
	==> { fail nonterminal };
}

@ =
text_stream *BinaryPredicates::get_log_name(binary_predicate *bp) {
	return bp->debugging_log_name;
}

@h Miscellaneous access routines.

=
parse_node *BinaryPredicates::get_bp_created_at(binary_predicate *bp) {
	return bp->bp_created_at;
}

@ Details of the terms:

=
kind *BinaryPredicates::term_kind(binary_predicate *bp, int t) {
	if (bp == NULL) internal_error("tried to find kind of null relation");
	return BPTerms::kind(&(bp->term_details[t]));
}
i6_schema *BinaryPredicates::get_term_as_fn_of_other(binary_predicate *bp, int t) {
	if (bp == NULL) internal_error("tried to find function of null relation");
	return bp->term_details[t].function_of_other;
}

@ Reversing:

=
binary_predicate *BinaryPredicates::get_reversal(binary_predicate *bp) {
	if (bp == NULL) internal_error("tried to find reversal of null relation");
	return bp->reversal;
}
int BinaryPredicates::is_the_wrong_way_round(binary_predicate *bp) {
	if ((bp) && (bp->right_way_round == FALSE)) return TRUE;
	return FALSE;
}

@ For compiling code from conditions:

=
i6_schema *BinaryPredicates::get_test_function(binary_predicate *bp) {
	return bp->task_functions[TEST_ATOM_TASK];
}
int BinaryPredicates::can_be_made_true_at_runtime(binary_predicate *bp) {
	if ((bp->task_functions[NOW_ATOM_TRUE_TASK]) ||
		(bp->reversal->task_functions[NOW_ATOM_TRUE_TASK])) return TRUE;
	return FALSE;
}

@ For the A-parser. The real code is all elsewhere; note that the
|assertions| field, which is used only for relations between values rather
than objects, is a linked list. (Information about objects is stored in
linked lists pointed to from the |instance| structure in question; that
can't be done if an assertion is about values, so they are stored under the
relation itself.)

=
int BinaryPredicates::store_dynamically(binary_predicate *bp) {
	return bp->dynamic_memory;
}
int BinaryPredicates::relates_values_not_objects(binary_predicate *bp) {
	return bp->relates_values_not_objects;
}
TERM_DOMAIN_CALCULUS_TYPE *BinaryPredicates::as_subject(binary_predicate *bp) {
	return bp->knowledge_about_bp;
}

@ For use when optimising code.

=
int BinaryPredicates::allows_function_simplification(binary_predicate *bp) {
	return bp->allow_function_simplification;
}

@ The predicate-calculus engine compiles much better loops if
we can help it by providing an I6 schema of a loop header solving the
following problem:

Loop a variable $v$ (in the schema, |*1|) over all possible $x$ such that
$R(x, t)$, for some fixed $t$ (in the schema, |*2|).

If we can't do this, it will still manage, but by the brute force method
of looping over all $x$ in the left domain of $R$ and testing every possible
$R(x, t)$.

=
int BinaryPredicates::write_optimised_loop_schema(i6_schema *sch, binary_predicate *bp) {
	if (bp == NULL) return FALSE;
	@<Try loop ranger optimisation@>;
	@<Try loop parent optimisation subject to a proviso@>;
	return FALSE;
}

@ Some relations $R$ provide a "ranger" routine, |R|, which is such that
|R(t)| supplies the first "child" of $t$ and |R(t, n)| supplies the next
"child" after $n$. Thus |R| iterates through some linked list of all the
objects $x$ such that $R(x, t)$.

@<Try loop ranger optimisation@> =
	if (bp->loop_parent_optimisation_ranger) {
		Calculus::Schemas::modify(sch,
			"for (*1=%s(*2): *1: *1=%s(*2,*1))",
			bp->loop_parent_optimisation_ranger,
			bp->loop_parent_optimisation_ranger);
		return TRUE;
	}

@ Other relations make use of the I6 object tree, in cases where $R(x, t)$
is true if and only if $t$ is an object which is the parent of $x$ in the
I6 object tree and some routine associated with $R$, called its
proviso |P|, is such that |P(x) == t|. For example, ${\it worn-by}(x, t)$
is true iff $t$ is the parent of $x$ and |WearerOf(x) == t|. The proviso
ensures that we don't falsely pick up, say, items carried by $t$ which
aren't being worn, or aren't even clothing.

@<Try loop parent optimisation subject to a proviso@> =
	if (bp->loop_parent_optimisation_proviso) {
		Calculus::Schemas::modify(sch,
			"objectloop (*1 in *2) if (%s(*1)==parent(*1))",
			bp->loop_parent_optimisation_proviso);
		return TRUE;
	}