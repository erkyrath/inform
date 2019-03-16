# Inform 7 version 7.10.1 'Krypton' (build 6Q21)

## About Inform 7

Inform 7 (April 2006-) is a programming language for creating interactive
fiction, using natural language syntax. Using natural language and drawing on
ideas from linguistics and from literate programming, Inform is widely
used as a medium for literary writing, as a prototyping tool in the games
industry, and in education, both at school and university level (where
Inform is often assigned material for courses on digital narrative).
It has several times ranked in the top 100 most influential programming
languages according to the TIOBE index.

## Licence

Except as noted, copyright in material in this repository (the "Package") is
held by Graham Nelson (the "Author"), who retains copyright so that there is
a single point of reference. As from the first date of this repository
becoming public, the Package is placed under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).
This is a highly permissive licence, used by Perl among other notable projects,
recognised by the Open Source Initiative as open and by the Free Software
Foundation as free in both senses.

For the avoidance of doubt, the Author makes the further grant that users of
the Package may make unlimited use of story files produced by the Package:
such story files are not derivative works of Inform and do not inherit the
Artistic License 2.0 as an obligation. (This further grant follows the
practice of projects like bison, which also copy substantial code into
their outputs.)

## Repositories

This is the "core repository", holding source code for the compiler, and
for everything needed to run it on the command line. However:

* To build and test the compiler you also need Inweb and Intest, programs
spun out from the Inform project. These are __not included in the core
repository either as submodules or copies__, and have their own repositories.
	* [https://github.com/ganelson/inweb](https://github.com/ganelson/inweb), maintained by [Graham Nelson](https://github.com/ganelson)
	* [https://github.com/ganelson/intest](https://github.com/ganelson/intest), maintained by [Graham Nelson](https://github.com/ganelson)
* Most Inform authors use Inform as an app: for example, it is available
on the Mac App Store. While much of the UI design is the same across all
platforms, each app has its own code in its own repository. See:
	* [https://github.com/TobyLobster/Inform](https://github.com/TobyLobster/Inform) for MacOS, maintained by [Toby Nelson](https://github.com/TobyLobster)
	* [https://github.com/DavidKinder/Windows-Inform7](https://github.com/DavidKinder/Windows-Inform7) for Windows, maintained by [David Kinder](https://github.com/DavidKinder)
	* [https://github.com/ptomato/gnome-inform7](https://github.com/ptomato/gnome-inform7) for Linux, maintained by [Philip Chimento](https://github.com/ptomato)

## Build Instructions

Make a directory in which to work: let's call this "work". Then:

* Clone and build Inweb into "work/inweb": repository [here](https://github.com/ganelson/inweb).
* Clone and build Intest into "work/intest": repository [here](https://github.com/ganelson/intest).
* Clone Inform into "work/inform". Change the current directory to that.
Then run "bash scripts/first.sh" (or whatever shell you prefer: it need
not be bash). This should give you a complete working set of command-line
Inform tools and associated makefiles. For any future builds, you can simply
type "make".
* For a simple test, try e.g. "inblorb/Tangled/inblorb -help". All the
executables should similarly respond to -help.
* But for a true test, run "make check". This compiles two more tools needed
only for testing (dumb-frotz and dumb-glulx), then runs Intest on each tool
in turn. Some haven't got a test suite, some have; it will run whatever it
finds. Be advised that on a 2013 laptop this all takes quarter of an hour and
sounds like a helicopter taking off.

## Inventory

**"I can't help feeling that if someone had asked me before the universe began
how it would turn out, I should have guessed something a bit less like an old
curiosity shop and a bit more like a formal French garden — an orderly
arrangement of straight avenues, circular walks, and geometrically shaped
trees and hedges."** (Michael Frayn)

Inform is not a single program, but an assemblage of programs and resources.
Some, including the inform7 compiler itself, are "literate programs", also
called "webs". The notation &#9733; marks these, and links are provided to
their human-readable forms. (This will be enabled when the repository
becomes public: GitHub Pages does not work on private repositories.)

### Resources for which this is the primary repository

This repository is where development is done on the following executables:

* inform7 - The core compiler in a natural-language design system for interactive fiction. - __version 7.10.1 'Krypton' (build 6Q21)__ - [&#9733;&nbsp;Web](docs/inform7/index.html)

	* its modules [&#9733;&nbsp;words](docs/words-module/index.html), [&#9733;&nbsp;inflections](docs/inflections-module/index.html), [&#9733;&nbsp;syntax](docs/syntax-module/index.html), [&#9733;&nbsp;problems](docs/problems-module/index.html), [&#9733;&nbsp;linguistics](docs/linguistics-module/index.html), [&#9733;&nbsp;kinds](docs/kinds-module/index.html), [&#9733;&nbsp;core](docs/core-module/index.html), [&#9733;&nbsp;if](docs/if-module/index.html), [&#9733;&nbsp;multimedia](docs/multimedia-module/index.html), [&#9733;&nbsp;index](docs/index-module/index.html)
	* their unit test executables [&#9733;&nbsp;words-test](docs/words-test/index.html), [&#9733;&nbsp;inflections-test](docs/inflections-test/index.html), [&#9733;&nbsp;syntax-test](docs/syntax-test/index.html), [&#9733;&nbsp;problems-test](docs/problems-test/index.html), [&#9733;&nbsp;linguistics-test](docs/linguistics-test/index.html), [&#9733;&nbsp;kinds-test](docs/kinds-test/index.html), [&#9733;&nbsp;core-test](docs/core-test/index.html)
* inblorb - The packaging stage of the Inform 7 system, which releases a story file in the blorbed format. - __version 4 'Duralumin'__ - [&#9733;&nbsp;Web](docs/inblorb/index.html)

* indoc - The documentation-formatter for the Inform 7 system. - __version 4 'Didache'__ - [&#9733;&nbsp;Web](docs/indoc/index.html)

* inpolicy - A lint-like tool to check up on various policies used in Inform source code. - __version 1 'Plan A'__ - [&#9733;&nbsp;Web](docs/inpolicy/index.html)

* inrtps - A generator of HTML pages to show for run-time problem messages in Inform. - __version 2 'Benefactive'__ - [&#9733;&nbsp;Web](docs/inrtps/index.html)

* inter - For handling intermediate Inform code. - __version 1 'Axion'__ - [&#9733;&nbsp;Web](docs/inter/index.html)

	* its modules [&#9733;&nbsp;inter](docs/inter-module/index.html), [&#9733;&nbsp;codegen](docs/codegen-module/index.html)
* srules - The Standard Rules extension, included in all Inform 7 works. - __version 5/190315__ - [&#9733;&nbsp;Web](docs/srules/index.html)


The inform7 subtree further contains these primary resources:

* The I6 Template - The .i6t files used in code generation. Inform 6; held in inform7/Internal/I6T
* inform7/Internal/Extensions - Libraries of code. Inform 7
	* inform7/Internal/Extensions/Emily Short/Basic Help Menu.i7x - __unversioned__

	* inform7/Internal/Extensions/Emily Short/Basic Screen Effects.i7x - __version 7/140425__

	* inform7/Internal/Extensions/Emily Short/Complex Listing.i7x - __version 9__

	* inform7/Internal/Extensions/Emily Short/Glulx Entry Points.i7x - __version 10/140425__

	* inform7/Internal/Extensions/Emily Short/Glulx Image Centering.i7x - __version 4__

	* inform7/Internal/Extensions/Emily Short/Glulx Text Effects.i7x - __version 5/140516__

	* inform7/Internal/Extensions/Emily Short/Inanimate Listeners.i7x - __unversioned__

	* inform7/Internal/Extensions/Emily Short/Locksmith.i7x - __version 12__

	* inform7/Internal/Extensions/Emily Short/Menus.i7x - __version 3__

	* inform7/Internal/Extensions/Emily Short/Punctuation Removal.i7x - __version 5__

	* inform7/Internal/Extensions/Emily Short/Skeleton Keys.i7x - __unversioned__

	* inform7/Internal/Extensions/Eric Eve/Epistemology.i7x - __version 9__

	* inform7/Internal/Extensions/Graham Nelson/Approximate Metric Units.i7x - __version 1__

	* inform7/Internal/Extensions/Graham Nelson/English Language.i7x - __version 1__

	* inform7/Internal/Extensions/Graham Nelson/Metric Units.i7x - __version 2__

	* inform7/Internal/Extensions/Graham Nelson/Rideable Vehicles.i7x - __version 3__

	* inform7/Internal/Extensions/Graham Nelson/Unicode Character Names.i7x - __unversioned__

	* inform7/Internal/Extensions/Graham Nelson/Unicode Full Character Names.i7x - __unversioned__

* inform7/Internal/HTML - Files needed for generating extension documentation and the like. HTML, Javascript, CSS
* inform7/Internal/Languages - Natural language definition bundles
* inform7/Internal/Templates - template websites for Inform 7's 'release as a website' feature
	* inform7/Internal/Templates/Classic - An older, plainer website - __unversioned__

	* inform7/Internal/Templates/Standard - The default, more modern look - __unversioned__


The "resources" directory holds a number of non-executable items of use to the
Inform UI applications, and to Inform websites:

* Changes to Inform - A detailed change history of Inform 7. Ebook in Indoc format, stored at path resources/Changes.

* Writing with Inform and the Inform Recipe Book - The main Inform documentation, as seen in the apps, and in standalone Epubs. Ebook in Indoc format, stored at path resources/Documentation.

* resources/Outcome Pages - Inrtps uses these to generate HTML outcome pages (such as those showing Problem messages in the app)
* resources/Sample Projects - Two small interactive fictions, 'Disenchantment Bay' and 'Onyx', presented as samples in the app. Inform 7

Finally, the "retrospective" directory holds ANSI C source and resources needed
to build (some) previous versions of Inform 7. At present, this is only sketchily
put together.

### Resources copied here from elsewhere

Stable versions of the following are periodically copied into this repository,
but this is not where development on them is done, and no pull requests will
be accepted. (Note that these are not git submodules.)

* inform6 - The Inform 6 compiler (used by I7 as a code generator). - __version 1634 '5th March 2016'__ - from [https://github.com/DavidKinder/Inform6], maintained by [David Kinder](https://github.com/DavidKinder)


* inform7/Internal/Templates - template websites for Inform 7's 'release as a website' feature
	* inform7/Internal/Templates/Parchment - Z-machine in Javascript - __version 'Parchment for Inform 7 (2015-09-25)'__ - from [https://github.com/curiousdannii/parchment], maintained by [Dannii Willis](https://github.com/curiousdannii)

	* inform7/Internal/Templates/Quixe - Glulx in Javascript - __version 'Quixe for Inform 7 (v. 2.1.2)'__ - from [https://github.com/erkyrath/quixe], maintained by [Andrew Plotkin](https://github.com/erkyrath)

	* inform7/Internal/Templates/Vorple - Multimedia in Javascript - __version 'Vorple'__ - from [https://github.com/vorple/inform7], maintained by [Juhana Leinonen](https://github.com/vorple)


### Binary resources (such as image files)

* resources/Imagery/app_images - icons for the Inform app and its many associated files, in MacOS format
* resources/Imagery/bg_images - background textures used in the Index generated by Inform
* resources/Imagery/doc_images - miscellaneous images needed by the documentation
* resources/Imagery/map_icons - images needed for the World pane of the Index generated by Inform
* resources/Imagery/outcome_images - images used on outcome pages
* resources/Imagery/scene_icons - images needed for the Scenes pane of the Index generated by Inform
* resources/Internal/Miscellany - default cover art, the Introduction to IF and Postcard PDFs

### Other files and folders in this repository

* docs - Woven forms of the webs, for serving by GitHub Pages (**not yet added**)
* scripts/gitignorescript.txt - Inweb uses this to generate the .gitignore file at the root of the repository
* scripts/makescript.txt - Inweb uses this to generate a makefile at the root of the repository
* scripts/READMEscript.txt - Inpolicy uses this to generate the README.md file for the repository

### Colophon

This README.mk file was generated automatically by Inpolicy, and should not
be edited. To make changes, edit scripts/READMEscript.txt and re-generate.

