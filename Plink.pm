#! /usr/bin/env perl

package Plink;

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
            chomp $line;
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
