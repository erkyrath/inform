Glulx and Glk.

Support for Glulx and Glk interpreter systems.

@ =
Part Four - Glulx and Glk (for Glulx only)

@h Glk windows.
Minimal support for Glk windows. Other extensions may extend the kind.

=
Chapter - Glk windows

A glk window is a kind of abstract object.
The glk window kind is accessible to Inter as "K_Glk_Window".
The specification of a glk window is "Models the Glk window system."

A glk window has a glk window type called the type.
The type property translates into Inter as "glk_window_type".

A glk window has a number called the rock number.
The rock number property translates into Inter as "glk_rock".

A glk window has a number called the reference number.
The reference number property translates into Inter as "glk_ref".

A glk window has a text input status.
The text input status property translates into Inter as "input_status".

A glk window can be requesting mouse input.
The requesting mouse input property translates into Inter as "requesting_mouse".

A glk window can be requesting hyperlink input.
The requesting hyperlink input property translates into Inter as "requesting_hyperlink".

@ Create objects for each of the built in windows, as well as the "unknown window",
which is used when there's a Glk event on a window that can't be identified.

=
The main window is a glk window.
The main window object is accessible to Inter as "Main_Window".
The type of the main window is text buffer.

The status window is a glk window.
The status window object is accessible to Inter as "Status_Window".
The type of the status window is text grid.

The quote window is a glk window.
The quote window object is accessible to Inter as "Quote_Window".
The type of the quote window is text buffer.

The unknown window is a glk window.
The unknown window object is accessible to Inter as "Unknown_Glk_Window".

@h Feature testing.
These phrases let us test for various interpreter features.
While most features can use the generic functions, a few need special handling,
and so individual phrases are defined for them.

=
Chapter - Glk and Glulx feature testing

To decide whether (F - glk feature) is/are supported:
	(- glk_gestalt({F}) -).

To decide what number is the glk version number/--:
	(- glk_gestalt(gestalt_Version) -).

To decide whether buffer window graphics are/is supported:
	(- glk_gestalt(gestalt_DrawImage, winType_TextBuffer) -).

To decide whether graphics window graphics are/is supported:
	(- glk_gestalt(gestalt_DrawImage, winType_Graphics) -).

To decide whether graphics window mouse input is supported:
	(- glk_gestalt(gestalt_MouseInput, winType_Graphics) -).

To decide whether grid window mouse input is supported:
	(- glk_gestalt(gestalt_MouseInput, winType_TextGrid) -).

To decide whether (F - glulx feature) is/are supported:
	(- Glulx_Gestalt({F}) -).

To decide what number is the glulx version number/--:
	(- Glulx_Gestalt(GLULX_GESTALT_GlulxVersion) -).

To decide what number is the interpreter version number/--:
	(- Glulx_Gestalt(GLULX_GESTALT_TerpVersion) -).

@h Glk object recovery.
These rules are a low level system for managing Glk references. When a Glulx
game restarts and restores, the current Glk IO state is not reset. All the old
windows, sound channels etc. will be kept as they were, even though the game file
might be expecting a different state. This extension allows Inform 7 game files
to ensure that the IO state is as it should be. It does this in three stages:

(a) The "reset glk references rules" is run. Rules should be added to reset all
Glk references as if none existed.

(b) The "identify glk windows rules" etc. are run. These rulebooks will be run
once for each Glk IO object which currently exists. Objects can be identified
through the current glk object rock number and current glk object reference
number variables.

(c) The "glk object updating rules" is run. Rules should be added to correct the
Glk IO state by, for example, closing windows which shouldn't exist, and opening
windows which should but currently do not.

=
Chapter - Glk object recovery

The current glk object rock number is a number that varies.
The current glk object rock number variable translates into Inter as "current_glk_object_rock".
The current glk object reference number is a number that varies.
The current glk object reference number variable translates into Inter as "current_glk_object_reference".

The reset glk references rules is a rulebook.
The reset glk references rules is accessible to Inter as "RESET_GLK_REFERENCES_RB".
The identify glk windows rules is a rulebook.
The identify glk windows rules is accessible to Inter as "IDENTIFY_WINDOWS_RB".
The identify glk streams rules is a rulebook.
The identify glk streams rules is accessible to Inter as "IDENTIFY_STREAMS_RB".
The identify glk filerefs rules is a rulebook.
The identify glk filerefs rules is accessible to Inter as "IDENTIFY_FILEREFS_RB".
The identify glk sound channels rules is a rulebook.
The identify glk sound channels rules is accessible to Inter as "IDENTIFY_SCHANNELS_RB".
The glk object updating rules is a rulebook.
The glk object updating rules is accessible to Inter as "GLK_OBJECT_UPDATING_RB".

@ And the standard rules, which may be replaced by extensions.

=
The reset glk references for built in objects rule is listed first in the reset glk references rules.
The reset glk references for built in objects rule translates into Inter as "RESET_GLK_REFERENCES_R".

The identify built in windows rule is listed first in the identify glk windows rules.
The identify built in windows rule translates into Inter as "IDENTIFY_WINDOWS_R".

The identify built in streams rule is listed first in the identify glk streams rules.
The identify built in streams rule translates into Inter as "IDENTIFY_STREAMS_R".

The identify built in filerefs rule is listed first in the identify glk filerefs rules.
The identify built in filerefs rule translates into Inter as "IDENTIFY_FILEREFS_R".

The identify built in sound channels rule is listed first in the identify glk sound channels rules.
The identify built in sound channels rule translates into Inter as "IDENTIFY_SCHANNELS_R".

The stop built in sound channels rule is listed in the glk object updating rules.
The stop built in sound channels rule translates into Inter as "STOP_SCHANNELS_R".

@h Glk events.
Glk events can be handled with the glk event handling rules.

=
Chapter - Glk events

The glk event handling rules is a glk event based rulebook.
The glk event handling rules is accessible to Inter as "GLK_EVENT_HANDLING_RB".

The glk event type is a glk event variable.
The glk event type variable translates into Inter as "Glk_Event_Struct_type".
The glk event window is a glk window variable.
The glk event window variable translates into Inter as "Glk_Event_Struct_win".
The glk event value 1 is a number variable.
The glk event value 1 variable translates into Inter as "Glk_Event_Struct_val1".
The glk event value 2 is a number variable.
The glk event value 2 variable translates into Inter as "Glk_Event_Struct_val2".

Definition: a glk event is dependent on the player rather than independent of the player if
	it is character event or
	it is line event or
	it is mouse event or
	it is hyperlink event.
