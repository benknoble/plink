# NAME

Plink, plink - the DSL-for-dotfiles program

# SYNOPSIS

    # command-line usage
    # head -n 1 dotfiles.plink
    #! /usr/bin/env /path/to/Plink.pm
    # ./dotfiles.plink
    # make

[![This project is considered stable](https://img.shields.io/badge/status-stable-success.svg)](https://benknoble.github.io/status/stable/)

# DESCRIPTION

The **Plink** module provides an implementation of the Plink language, a DSL
built to describe dotfiles via symlinks. The language is a strict superset of
make(1); implementations produce (POSIX) makefiles for use. It is important to
note that Plink only guarantees that generated code is POSIX-compatible.
User-written code may use GNU make or other non-portable features. What follows
is the canonical specification of the Plink language.

## Plink Specification

Plink is superset of POSIX make. It defines four (4) new syntaxes with semantic
meaning.

Plink also defines a header and footer.

A conforming implementation transforms the input file (or STDIN) as specified by
the syntaxes. All lines not participating in one of these syntaxes, in addition
to `#` comments, are copied verbatim (this includes blank lines). The output is
written to a file named by the environment variable `PLINK_OUTPUT`, or
`Makefile` if unset.

See `t/test.plink` for an example Plink file, and `t/expected.mk` for its
output.

### Square Brackets `[ prerequisites ]`

Any line like

    target names [ prerequisites ] ...

will be transformed to

    target names: $MAKEFILE prerequisites ...

`$MAKEFILE` denotes the name of the generated filename.  The spaces around
`[]` are not _required_, but often recommended. `...` may make use of any the
bang-syntaxes.

### Bang and Double-bang `!` `!!`

Lines like

    target ! commands

will be transformed to

    target:
    <TAB>commands

The list `commands` lasts to the end of the line. `commands` will be indented
by one tab, as make requires.

Similarly, lines like

    target !!
    commands
    on more lines
    !!

become

    target:
    <TAB>commands
    <TAB>on more lines

The list `commands` lasts until the line containing _exactly_ `!!`. Commands
will be tab-indented.

### Symlink (Fat-arrow) `<=`

The meat of the DSL. Lines like

    link_in_home <= dotfile_under_$(LINKS)

Become part of a mapping. The output creates dependencies of the form

    $(HOME)/link_in_home: $(LINKS)dotfile_under_$(LINKS)

for each fat-arrow, and also gives each the recipe

    if test -e $@ || test -L $@ ; then rm -rf $@ ; fi
    ln -s $$(python -c "from os.path import *; print(relpath('$?', start=dirname('$@')))") $@
    @echo $@ '->' $$(python -c "from os.path import *; print(relpath('$?', start=dirname('$@')))")

which creates the link. Finally, a target named `symlink` is provided which
depends on all the `link_in_home`s provided: it is considered the public API
for any make target that wishes to depend on symlink-generation.

Dotfiles are files under the make macro `$(LINKS)`. Due to the generation rule,
if `$(LINKS)` is not set, the current directory is used. This can be useful to
put all dotfiles under a directory named, e.g., `dots`. Then you want to
include a line in your Plink file like

    LINKS = dots/

(note the trailing slash).

The use of the macro `SYMLINKS` is considered a Plink implementation detail and
is subject to change; users who set `SYMLINKS` or depend on it's effects are
invoking undefined behavior.

### Header

The Plink header consists of

    SHELL = /bin/sh
    .SUFFIXES:

### Footer

The Plink footer consists of the symlink target implementation and the
following:

    MAKEFILE: INPUT
    <TAB>$$(python -c "from os.path import *; print(abspath('$?'))")

`MAKEFILE` refers to the generated output, and `INPUT` to the Plink file used
as input.

## Normal Usage

Since Plink is a superset of make, your current makefile is valid under Plink
and will be transformed to exactly itself. This means the quickest way to get
started is to move your makefile to a `.plink`-file, and edit the shebang to
point to `#! /usr/bin/env /path/to/Plink.pm`. If you don't have env(1), the
path to perl(1) should work.

Opt-in to Plink features by re-writing portions of your new Plink file to
take advantage of Plink.

Then, run your Plink file to generate a Makefile. Use make(1) to run your
targets! (Be sure to `chmod u+x ./some.plink`.). Note that all Plink-generated
targets depend on the generated Makefile, which depends on the Plink file
used to generate it. This means that users taking full advantage of Plink should
only need to `make` when they edit their Plink file.

## Advanced: Bypassing Plink

Omit Plink-level syntax to guarantee that no processing is done on your code.
The most common use of this is to disable Plink's insistence that everything
depends on the output file; do not specify pre-requisites in `[ square brackets
]` to ignore this.

# METHODS

_plink_ _$infname_, _$outfname_

Implements the Plink specification, transforming the file named `infname` to
`outfname`. Handles for STDIN and STDOUT are accepted, though STDIN has the
side-effect that the Makefile rules now depend on the literal file `STDIN`.
Similarly, STDOUT breaks the rule to make the generated Makefile.

# OPTIONS

- _Plink\_file_

    The Plink file from which to generate the output.

# DIAGNOSTICS

Enable diagnostics by putting `use diagnostics;` at the top of the module.

# EXAMPLES

See the `t` directory.

# ENVIRONMENT

- PLINK\_OUTPUT

    Used to determine where to write the output. Defaults to `Makefile`.

# FILES

See ["#ENVIRONMENT"](#environment).

# CAVEATS

See the [Specification](#plink-specification) for caveats on symlink
implementations.

# BUGS

Generated Makefiles may choke on paths with spaces. Avoid those for now.

# AUTHOR

D. Ben Knoble &lt;ben.knoble+plink@gmail.com>

# COPYRIGHT AND LICENSE

Copyright 2019 D. Ben Knoble

See `LICENSE`.

# SEE ALSO

make(1), [https://github.com/benknoble/Dotfiles](https://github.com/benknoble/Dotfiles), [https://github.com/benknoble/vim-plink](https://github.com/benknoble/vim-plink)
