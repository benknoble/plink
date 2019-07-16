#! /usr/bin/env perl

package Plink v1.0.0;

use v5.10;
use strict;
use warnings;
use autodie;

use open ':locale';
# implicit with
# use v5.10;
use feature 'unicode_strings';

use Exporter 'import';
our @EXPORT_OK = qw(plink);

main() unless caller(0);

sub trim {
    my $string = shift;
    $string =~ s/^\s+|\s+$//g;
    return $string;
}

sub process_deps {
    my ($line, $outfname) = @_;
    return $line if $line =~ /^#/;
    my ($target, $deps, $rest) = $line =~ m{^
        (.+)        # target
        \[(.*)\]    # dependencies
        (.*)        # anything else
    $}x;
    return $line unless $target;
    $target = trim $target;
    $rest = trim $rest;
    my @deps = grep(!/^\s*$/, map { trim $_ } (split /\s+/, $deps));
    return "$target: $outfname @deps $rest\n";
}

sub process_bang {
    my ($line, $outfname) = @_;
    $line = process_deps($line, $outfname);
    my ($target, $rest) = $line =~ m{^
        ([^!]+)    # target
        !          # bang
        ([^!]+)    # rest
    $}x;
    return unless $target;
    $rest = trim $rest;
    $target = trim $target;
    unless ($target =~ /:/) {
        $target = "$target:"
    }
    return <<TARGET;
$target
\t$rest
TARGET
}

sub print_header {
    my $out = shift;
    print $out <<HEADER;
SHELL = /bin/sh
.SUFFIXES:

HEADER
}

sub print_footer {
    my ($out, $outfname, $infname) = @_;
    print $out <<FOOTER;
# symlink: ensure symlinks created
symlink: $outfname \$(SYMLINKS)

\$(SYMLINKS):
\tif test -e \$@ ; then rm -rf \$@ ; fi
\tln -s \$\$(realpath \$?) \$@
\t\@echo \$@ '->' \$\$(realpath \$?)

$outfname: $infname
\t\$\$(realpath \$?)
FOOTER
}

sub process_lines {
    my ($in, $out, $outfname) = @_;
    my %links;

    while (my $line = <$in>) {
        next if ($line =~ m/^#!|^!!$/);
        # skip comments, no preprocessing
        if ($line =~ m/^#/) {
            print $out $line;
        }
        # !!
        elsif ($line =~ m/!!/) {
            (my $target = process_deps($line, $outfname)) =~ s/!!\s*$//;
            $target = trim $target;
            unless ($target =~ /:/) {
                $target = "$target:"
            }
            print $out "$target\n";
            while (my $sub_line = <$in>) {
                last if $sub_line =~ /!!/;
                print $out "\t$sub_line";
            }
        }
        # !
        elsif ($line =~ m/!/) {
            print $out process_bang($line, $outfname);
        }
        # <=
        elsif ($line =~ m/<=/) {
            my ($link, $dotfile) = map { trim $_ } split /<=/, $line;
            $links{$link} = $dotfile;
        }
        else {
            print $out process_deps($line, $outfname);
        }
    }

    return %links;
}

sub print_links {
    my ($out, %links) = @_;
    print $out "SYMLINKS = \\\n";
    # print %links
    for my $link (sort keys %links) {
        print $out "\$(HOME)/$link \\\n";
    }
    print $out "\n\n";

    for my $link (sort keys %links) {
        print $out "\$(HOME)/$link: \$(LINKS)$links{$link}\n";
    }
    print $out "\n";
}

sub get_in {
    my $infname = shift;
    if ($infname eq \*STDIN) {
        return ($infname, 'STDIN');
    }
    else {
        open(my $in, '<', $infname);
        return ($in, $infname);
    }
}

sub get_out {
    my $outfname = shift;
    if ($outfname eq \*STDOUT) {
        return ($outfname, 'STDOUT');
    }
    else {
        open(my $out, '>', $outfname);
        return ($out, $outfname);
    }
}

sub plink {
    my ($infname, $outfname) = @_;
    my ($in, $out);
    ($in, $infname) = get_in $infname;
    ($out, $outfname) = get_out $outfname;

    print_header $out;
    my %links = process_lines $in, $out, $outfname;
    print_links $out, %links;
    print_footer $out, $outfname, $infname;

    close($out);
    close($in);
}

sub main {
    my $output = $ENV{PLINK_OUTPUT} // 'Makefile';
    my $input = shift @ARGV // \*STDIN;
    plink $input, $output;
}

# return true
1;

__END__

=head1 NAME

Plink, plink - the DSL-for-dotfiles program

=head1 SYNOPSIS

    # command-line usage
    # head -n 1 dotfiles.plink
    #! /usr/bin/env /path/to/Plink.pm
    # ./dotfiles.plink
    # make

=begin markdown

[![This project is considered stable](https://img.shields.io/badge/status-stable-success.svg)](https://benknoble.github.io/status/stable/)

=end markdown

=head1 DESCRIPTION

The B<Plink> module provides an implementation of the Plink language, a DSL
built to describe dotfiles via symlinks. The language is a strict superset of
make(1); implementations produce (POSIX) makefiles for use. It is important to
note that Plink only guarantees that generated code is POSIX-compatible.
User-written code may use GNU make or other non-portable features. What follows
is the canonical specification of the Plink language.

=head2 Plink Specification

Plink is superset of POSIX make. It defines four (4) new syntaxes with semantic
meaning.

Plink also defines a header and footer.

A conforming implementation transforms the input file (or STDIN) as specified by
the syntaxes. All lines not participating in one of these syntaxes, in addition
to C<#> comments, are copied verbatim (this includes blank lines). The output is
written to a file named by the environment variable C<PLINK_OUTPUT>, or
C<Makefile> if unset.

See F<t/test.plink> for an example Plink file, and F<t/expected.mk> for its
output.

=head3 Square Brackets C<[ prerequisites ]>

Any line like

    target names [ prerequisites ] ...

will be transformed to

    target names: $MAKEFILE prerequisites ...

C<$MAKEFILE> denotes the name of the generated filename.  The spaces around
C<[]> are not I<required>, but often recommended. C<...> may make use of any the
bang-syntaxes.

=head3 Bang and Double-bang C<!> C<!!>

Lines like

    target ! commands

will be transformed to

    target:
    <TAB>commands

The list C<commands> lasts to the end of the line. C<commands> will be indented
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

The list C<commands> lasts until the line containing I<exactly> C<!!>. Commands
will be tab-indented.

=head3 Symlink (Fat-arrow) C<E<lt>=>

The meat of the DSL. Lines like

    link_in_home <= dotfile_under_$(LINKS)

Become part of a mapping. The output creates dependencies of the form

    $(HOME)/link_in_home: $(LINKS)dotfile_under_$(LINKS)

for each fat-arrow, and also gives each the recipe

    if test -e $@ ; then rm -rf $@ ; fi
    ln -s $$(realpath $?) $@
    @echo $@ '->' $$(realpath $?)

which creates the link. Finally, a target named C<symlink> is provided which
depends on all the C<link_in_home>s provided: it is considered the public API
for any make target that wishes to depend on symlink-generation.

Dotfiles are files under the make macro C<$(LINKS)>. Due to the generation rule,
if C<$(LINKS)> is not set, the current directory is used. This can be useful to
put all dotfiles under a directory named, e.g., C<dots>. Then you want to
include a link in your Plink file like

    LINKS = dots/

(note the trailing slash).

The use of the macro C<SYMLINKS> is considered a Plink implementation detail and
is subject to change; users who set C<SYMLINKS> or depend on it's effects are
invoking undefined behavior.

=head3 Header

The Plink header consists of

    SHELL = /bin/sh
    .SUFFIXES:

=head3 Footer

The Plink footer consists of the symlink target implementation and the
following:

    MAKEFILE: INPUT
    <TAB>$$(realpath $?)

C<MAKEFILE> refers to the generated output, and C<INPUT> to the Plink file used
as input.

=head2 Normal Usage

Since Plink is a superset of make, your current makefile is valid under Plink
and will be transformed to exactly itself. This means the quickest way to get
started is to move your makefile to a C<.plink>-file, and edit the shebang to
point to C<#! /usr/bin/env /path/to/Plink.pm>. If you don't have env(1), the
path to perl(1) should work.

Opt-in to Plink features by re-writing portions of your new Plink file to
take advantage of Plink.

Then, run your Plink file to generate a Makefile. Use make(1) to run your
targets! (Be sure to C<chmod u+x ./some.plink>.). Note that all Plink-generated
targets depend on the generated Makefile, which depends on the Plink file
used to generate it. This means that users taking full advantage of Plink should
only need to C<make> when they edit their Plink file.

=head2 Advanced: Bypassing Plink

Omit Plink-level syntax to guarantee that no processing is done on your code.
The most common use of this is to disable Plink's insistence that everything
depends on the output file; do not specify pre-requisites in C<[ square brackets
]> to ignore this.

=head1 METHODS

I<plink> I<$infname>, I<$outfname>

Implements the Plink specification, transforming the file named C<infname> to
C<outfname>. Hands for STDIN and STDOUT are accepted, though STDIN has the
side-effect that the Makefile rules now depend on the literal file C<STDIN>.
Similarly, STDOUT breaks the rule to make the generated Makefile.

=head1 OPTIONS

=over

=item I<Plink_file>

The Plink file from which to generate the output.

=back

=head1 DIAGNOSTICS

Enable diagnostics by putting C<use diagnostics;> at the top of the module.

=head1 EXAMPLES

See the F<t> directory.

=head1 ENVIRONMENT

=over

=item PLINK_OUTPUT

Used to determine where to write the output. Defaults to F<Makefile>.

=back

=head1 FILES

See L</#ENVIRONMENT>.

=head1 CAVEATS

See the L<Specification|/#plink-specification> for caveats on symlink
implementations.

=head1 BUGS

Generated Makefiles may choke on paths with spaces. Avoid those for now.

=head1 AUTHOR

D. Ben Knoble <ben.knoble+plink@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2019 D. Ben Knoble

See F<LICENSE>.

=head1 SEE ALSO

make(1), L<https://github.com/benknoble/Dotfiles>, L<https://github.com/benknoble/vim-plink>
