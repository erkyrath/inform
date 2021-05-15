[RTPropertyValues::] Emit Property Values.

To feed the hierarchy of instances and their property values, and kinds, into Inter.

@h Permissions.

=
void RTPropertyValues::emit_instance_permissions(instance *I) {
	inference_subject *subj = Instances::as_subject(I);
	property_permission *pp;
	LOOP_OVER_PERMISSIONS_FOR_INFS(pp, subj) {
		property *prn = pp->property_granted;
		if (Properties::is_either_or(prn))
			if (prn->compilation_data.store_in_negation) continue;
		Emit::instance_permission(prn, RTInstances::value_iname(I));
	}
}

@h Emitting the property values.
The following routine is called on every kind which can have properties,
and also on every individual instance of those kinds. Superkinds are called
before subkinds, and kinds are called before their instances, but we don't
manage that here.

=
inter_ti cs_sequence_counter = 0;
void RTPropertyValues::emit_subject(inference_subject *subj) {
	LOGIF(OBJECT_COMPILATION, "Compiling object definition for $j\n", subj);
	current_sentence = subj->infs_created_at;
	kind *K = KindSubjects::to_kind(subj);
	instance *I = InstanceSubjects::to_instance(subj);

	inter_name *iname = NULL;
	if (K) iname = RTKindDeclarations::iname(K);
	else if (I) iname = RTInstances::value_iname(I);
	else internal_error("bad subject for emission");

	Produce::annotate_i(iname, DECLARATION_ORDER_IANN, cs_sequence_counter++);

	@<Compile the actual object@>;
	LOGIF(OBJECT_COMPILATION, "Compilation of $j complete\n", subj);
}

@ We need to compile |with| or |has| clauses for all the properties our
object will have, and we need to be careful not to compile them more than
once, even if there's more than one permission recorded for a given
property; so we do this with a "traverse" of the properties, in which
each one is marked when visited.

@<Compile the actual object@> =
	@<Annotate with the spatial depth@>;
	@<Append any inclusions the source text requested@>;
	RTPropertyValues::begin_traverse();
	@<Emit inferred object properties@>;
	@<Emit permitted but unspecified object properties@>;

@<Annotate with the spatial depth@> =
	#ifdef IF_MODULE
	if ((I) && (Kinds::Behaviour::is_object(Instances::to_kind(I)))) {
		int AC = Spatial::get_definition_depth(I);
		if (AC > 0) Produce::annotate_i(iname, ARROW_COUNT_IANN, (inter_ti) AC);
	}
	#endif

@ This is an ugly business, but the I7 language supports the injection of raw
I6 code into object bodies. In an ideal world we would revoke this ability;
the Standard Rules do not use it.

@<Append any inclusions the source text requested@> =
	Interventions::make_for_subject(iname, subj);

@ Now, here goes with the properties. We first compile clauses for those we
know about, then for any other properties which are permitted but apparently
not set. Note that we only look through knowledge and permissions associated
with |subj| itself; we've no need to look at those for its kind (and its kind's
kind, and so on) because the Inform 6 compiler automatically inherits those
through the |Class| hierarchy of I6 objects -- this is why we have made
the class hierarchy at I6 level exactly match the kind hierarchy at I7 level.

@<Emit inferred object properties@> =
	inference *inf;
	KNOWLEDGE_LOOP(inf, subj, property_inf) {
		property *prn = PropertyInferences::get_property(inf);
		current_sentence = Inferences::where_inferred(inf);
		LOGIF(OBJECT_COMPILATION, "Compiling property $Y\n", prn);
		RTPropertyValues::emit_propertyvalue(subj, prn);
	}

@ We now wander through the permitted properties, even those which we have
no actual knowledge about.

@<Emit permitted but unspecified object properties@> =
	inference_subject *infs;
	for (infs = subj; infs; infs = InferenceSubjects::narrowest_broader_subject(infs)) {
		property_permission *pp;
		LOOP_OVER_PERMISSIONS_FOR_INFS(pp, infs) {
			property *prn = PropertyPermissions::get_property(pp);
			if ((infs == subj) ||
				(Kinds::Behaviour::uses_block_values(ValueProperties::kind(prn))))
				RTPropertyValues::emit_propertyvalue(subj, prn);
		}
	}

@ Either way, then, we end up here. The following works out what initial
value the property will have, and compiles a clause as appropriate.

=
int RTPropertyValues::emit_propertyvalue(inference_subject *know, property *prn) {
	package_request *R = NULL;
	instance *I = InstanceSubjects::to_instance(know);
	if (I) R = RTInstances::package(I);
	kind *K = KindSubjects::to_kind(know);
	if (K) R = RTKindConstructors::kind_package(K);
	int storage_cost = 0;
	if ((RTPropertyValues::visited_in_traverse(prn) == FALSE) &&
		(RTProperties::can_be_compiled(prn))) {
		if ((Properties::is_either_or(prn)) &&
			(RTProperties::stored_in_negation(prn)))
			prn = EitherOrProperties::get_negation(prn);
		value_holster VH = Holsters::new(INTER_DATA_VHMODE);
		Properties::compile_inferred_value(&VH, know, prn);
		@<Now emit a propertyvalue@>;
	}
	return storage_cost;
}

@<Now emit a propertyvalue@> =
	instance *as_I = InstanceSubjects::to_instance(know);
	kind *as_K = KindSubjects::to_kind(know);
	inter_ti v1 = LITERAL_IVAL, v2 = (inter_ti) FALSE;
	property *in = prn;

	Holsters::unholster_pair(&VH, &v1, &v2);

	if ((Properties::is_either_or(prn)) && (RTProperties::recommended_as_attribute(prn))) {
		if (RTProperties::stored_in_negation(prn)) {
			in = EitherOrProperties::get_negation(prn);
			v2 = (inter_ti) (v2)?FALSE:TRUE;
		}
	}
	if (as_I) Emit::instance_propertyvalue(in, as_I, v1, v2);
	else Emit::propertyvalue(in, as_K, v1, v2);

@ These functions are to help other parts of Inform to visit each property just
once, when working through some complicated search space. (Visiting an either/or
property also visits its negation.)

=
int property_traverse_count = 0;
void RTPropertyValues::begin_traverse(void) {
	property_traverse_count++;
}

int RTPropertyValues::visited_in_traverse(property *prn) {
	if (prn->compilation_data.visited_on_traverse == property_traverse_count) return TRUE;
	prn->compilation_data.visited_on_traverse = property_traverse_count;
	if (Properties::is_either_or(prn)) {
		property *prnbar = EitherOrProperties::get_negation(prn);
		if (prnbar) prnbar->compilation_data.visited_on_traverse = property_traverse_count;
	}
	return FALSE;
}

@h Attribute allocation.
At some later stage the business of deciding which properties are stored
at I6 run-time as attributes will be solely up to the code generator.
For now, though, we make a parallel decision here.

=
void RTPropertyValues::allocate_attributes(void) {
	int slots_given_away = 0;
	property *prn;
	LOOP_OVER(prn, property) {
		if ((Properties::is_either_or(prn)) &&
			(RTProperties::stored_in_negation(prn) == FALSE)) {
			int make_attribute = NOT_APPLICABLE;
			@<Any either/or property which some value can hold is ineligible@>;
			@<An either/or property translated to an existing attribute must be chosen@>;
			@<Otherwise give away attribute slots on a first-come-first-served basis@>;
			RTProperties::recommend_storing_as_attribute(prn, make_attribute);
		}
	}
}

@<Any either/or property which some value can hold is ineligible@> =
	property_permission *pp;
	LOOP_OVER_PERMISSIONS_FOR_PROPERTY(pp, prn) {
		inference_subject *infs = PropertyPermissions::get_subject(pp);
		if ((InferenceSubjects::is_an_object(infs) == FALSE) &&
			(InferenceSubjects::is_a_kind_of_object(infs) == FALSE))
			make_attribute = FALSE;
	}

@<An either/or property translated to an existing attribute must be chosen@> =
	if (RTProperties::has_been_translated(prn)) make_attribute = TRUE;

@<Otherwise give away attribute slots on a first-come-first-served basis@> =
	if (make_attribute == NOT_APPLICABLE) {
		if (slots_given_away++ < ATTRIBUTE_SLOTS_TO_GIVE_AWAY)
			make_attribute = TRUE;
		else
			make_attribute = FALSE;
	}

@h Rapid run-time testing.
The preferred way to access either/or properties of an object at run-time
is to use the pair of routines |GetEitherOrProperty| or
|SetEitherOrProperty|, defined in the I6 template, because that way
suitable run-time problems are generated for mistaken accesses. But if we
want the fastest possible access and know that it will be valid, we can use
the following.

=
void RTPropertyValues::emit_iname_has_property(kind *K, inter_name *N, property *prn) {
	RTPropertyValues::emit_has_property(K, InterNames::to_symbol(N), prn);
}
void RTPropertyValues::emit_has_property(kind *K, inter_symbol *S, property *prn) {
	if (RTProperties::recommended_as_attribute(prn)) {
		if (RTProperties::stored_in_negation(prn)) {
			EmitCode::inv(NOT_BIP);
			EmitCode::down();
				EmitCode::inv(HAS_BIP);
				EmitCode::down();
					EmitCode::val_symbol(K, S);
					EmitCode::val_iname(K_value, RTProperties::iname(EitherOrProperties::get_negation(prn)));
				EmitCode::up();
			EmitCode::up();
		} else {
			EmitCode::inv(HAS_BIP);
			EmitCode::down();
				EmitCode::val_symbol(K, S);
				EmitCode::val_iname(K_value, RTProperties::iname(prn));
			EmitCode::up();
		}
	} else {
		if (RTProperties::stored_in_negation(prn)) {
			EmitCode::inv(EQ_BIP);
			EmitCode::down();
				EmitCode::inv(PROPERTYVALUE_BIP);
				EmitCode::down();
					EmitCode::val_symbol(K, S);
					EmitCode::val_iname(K_value, RTProperties::iname(EitherOrProperties::get_negation(prn)));
				EmitCode::up();
				EmitCode::val_false();
			EmitCode::up();
		} else {
			EmitCode::inv(EQ_BIP);
			EmitCode::down();
				EmitCode::inv(PROPERTYVALUE_BIP);
				EmitCode::down();
					EmitCode::val_symbol(K, S);
					EmitCode::val_iname(K_value, RTProperties::iname(prn));
				EmitCode::up();
				EmitCode::val_true();
			EmitCode::up();
		}
	}
}

@h In-table storage.
Some kinds of non-object are created by table, with the table columns holding the
relevant property values. The following structure indicates which column of
which table will store the property values at run-time, or else is left as
|-1, 0| if the property values aren't living inside a table structure.

=
typedef struct property_of_value_storage {
	struct inter_name *storage_table_iname; /* for the relevant column array */
	CLASS_DEFINITION
} property_of_value_storage;

property_of_value_storage *latest_povs = NULL; /* see below */

@ It's a little inconvenient to work out some elegant mechanism for the table
compilation code to tell each kind where it will be living, so instead we
rely on the fact that we're doing one at a time. The table-compiler simply
calls this routine to notify us of where the next batch of properties will be,
and we mark them down in the most recently created property permission.

=
property_of_value_storage *RTPropertyValues::get_storage(void) {
	property_of_value_storage *povs = CREATE(property_of_value_storage);
	povs->storage_table_iname = NULL;
	latest_povs = povs;
	return povs;
}

void RTPropertyValues::pp_set_table_storage(inter_name *store) {
	if (latest_povs) {
		latest_povs->storage_table_iname = store;
	}
}

@ The code generator will need to know these numbers, so we will annotate
the property-permission symbol accordingly:

=
inter_name *RTPropertyValues::annotate_table_storage(property_permission *pp) {
	property_of_value_storage *povs =
		RETRIEVE_POINTER_property_of_value_storage(PropertyPermissions::get_storage_data(pp));
	return povs->storage_table_iname;
}


@ Here we produce property values for the kinds:

=
int RTPropertyValues::emit_property_values_for_kinds(inference_subject_family *f, int ignored) {
	RTPropertyValues::emit_pv_for_k_recursively(KindSubjects::from_kind(K_object));
	return FALSE;
}

void RTPropertyValues::emit_pv_for_k_recursively(inference_subject *within) {
	RTPropertyValues::emit_subject(within);
	inference_subject *subj;
	LOOP_OVER(subj, inference_subject)
		if ((InferenceSubjects::narrowest_broader_subject(subj) == within) &&
			(InferenceSubjects::is_a_kind_of_object(subj))) {
			RTPropertyValues::emit_pv_for_k_recursively(subj);
		}
}

void RTPropertyValues::emit_pv_for_one_kind(inference_subject_family *f,
	inference_subject *infs) {
	kind *K = KindSubjects::to_kind(infs);
	if ((KindSubjects::has_properties(K)) &&
		(Kinds::Behaviour::is_object(K) == FALSE))
		RTPropertyValues::emit_subject(infs);
	RTPropertyValues::check_kind_can_have_property(K);
}

@ This is a rather annoying provision, like everything to do with Inter
translation. But we don't want to hand the problem downstream to the code
generator; we want to deal with it now. The issue arises with source text like:

>> A keyword is a kind of value. The keywords are xyzzy, plugh. A keyword can be mentioned.

where "mentioned" is implemented for objects as an attribute in Inter.

That would make it impossible for the code-generator to store the property
instead in a flat array, which is how it will want to handle properties of
values. There are ways we could fix this, but property lookup needs to be fast,
and it seems best to reject the extra complexity needed.

=
void RTPropertyValues::check_kind_can_have_property(kind *K) {
	if (Kinds::Behaviour::is_object(K)) return;
	if (Kinds::Behaviour::definite(K) == FALSE) return;
	property *prn;
	property_permission *pp;
	instance *I_of;
	inference_subject *infs;
	LOOP_OVER_INSTANCES(I_of, K)
		for (infs = Instances::as_subject(I_of); infs;
			infs = InferenceSubjects::narrowest_broader_subject(infs))
			LOOP_OVER_PERMISSIONS_FOR_INFS(pp, infs)
				if (((prn = PropertyPermissions::get_property(pp))) &&
					(RTProperties::can_be_compiled(prn)) &&
					(problem_count == 0) &&
					(RTProperties::has_been_translated(prn)) &&
					(Properties::is_either_or(prn)))
					@<Bitch about our implementation woes, like it's not our fault@>;
}

@<Bitch about our implementation woes, like it's not our fault@> =
	current_sentence = PropertyPermissions::where_granted(pp);
	Problems::quote_source(1, current_sentence);
	Problems::quote_property(2, prn);
	Problems::quote_kind(3, K);
	StandardProblems::handmade_problem(Task::syntax_tree(), _p_(PM_AnomalousProperty));
	Problems::issue_problem_segment(
		"Sorry, but I'm going to have to disallow the sentence %1, even "
		"though it asks for something reasonable. A very small number "
		"of either-or properties with meanings special to Inform, like '%2', "
		"are restricted so that only kinds of object can have them. Since "
		"%3 isn't a kind of object, it can't be said to be %2. %P"
		"Probably you only need to call the property something else. The "
		"built-in meaning would only make sense if it were a kind of object "
		"in any case, so nothing is lost. Sorry for the inconvenience, all "
		"the same; there are good implementation reasons.");
	Problems::issue_problem_end();
