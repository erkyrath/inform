How To Include This Module.

What to do to make use of the kinds module in a new command-line tool.

@h Status.
The kinds module is provided as one of the "services" suite of modules,
which means that it was built with a view to potential incorporation in
multiple tools. It can be found, for example, in //inform7// and
//kinds-test//.

By convention, the modules considered as "services" have no dependencies on
other modules except for //foundation// and other "services" modules.

A tool can import //kinds// only if it also imports //foundation//,
//words//, //syntax//, //inflections// and //linguistics//.

@h Importing the module.
We'll use the term "parent" to mean the tool which is importing //kinds//,
that is, which will include its code and be able to use it. As with any
imported module,
(*) The contents page of the parent's web must identify and locate the
module:
= (text as Inweb)
Import: somepath/kinds
=
(*) The parent must call //KindsModule::start// just after it starts up, and
//KindsModule::end// just before it shuts down. (But just after, and just
before, the corresponding calls to //foundation//.)

@h Using callbacks.
Shared modules like this one are tweaked in behaviour by defining "callback
functions". This means that the parent might provide a function of its own
which would answer a question put to it by the module, or take some action
on behalf of the module: it's a callback in the sense that the parent is
normally calling the module, but then the module calls the parent back to
ask for data or action.

The parent must indicate which function to use by defining a constant with
a specific name as being equal to that function's name. A fictional example
would be
= (text as Inweb)
	@d EXPRESS_SURPRISE_KINDS_CALLBACK Emotions::whoa
	
	=
	void Emotions::whoa(text_stream *OUT) {
	    WRITE("Great heavens!\n");
	}
=
The following alphabetical list has references to fuller explanations:

(*) |NOTIFY_NATURAL_LANGUAGE_KINDS_CALLBACK| is called when the kind "natural
language" is created (if it is): see //FamiliarKinds::notice_new_kind//.

(*) |PROBLEM_KINDS_CALLBACK| is called when a syntax error is found, and can
prevent this from being issued to the terminal as an error message: see
//KindsModule::problem_handler//.
