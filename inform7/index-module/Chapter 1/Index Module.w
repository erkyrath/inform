[IndexModule::] Index Module.

Setting up the use of this module.

@ This section simoly sets up the module in ways expected by //foundation//, and
contains no code of interest. The following constant exists only in tools
which use this module:

@d INDEX_MODULE TRUE

@ Like all modules, this one must define a |start| and |end| function:

=

void IndexModule::start(void) {
}
void IndexModule::end(void) {
}
