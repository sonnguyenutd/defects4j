#!/usr/bin/env perl
#
#-------------------------------------------------------------------------------
# Copyright (c) 2014-2015 René Just, Darioush Jalali, and Defects4J contributors.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

=pod

=head1 NAME

minimize_patch.pl -- View and minimize patch in editor.

=head1 SYNOPSIS

minimize_patch.pl -p project_id -v version_id

=head1 OPTIONS

=over 4

=item B<-p C<project_id>>

The id of the project for which a patch should be minimized.

=item B<-v C<version_id>>

The id of the project version for which a patch should be minimized.

=back

=cut

use warnings;
use strict;
use FindBin;
use File::Basename;
use Cwd qw(abs_path);
use Getopt::Std;

use lib abs_path("$FindBin::Bin/../core");
use Constants;
use Project;

#
# Issue usage message and quit
#
sub _usage {
    die "usage: $0 -p project_id -v version_id"
}

my %cmd_opts;
getopts('p:v:', \%cmd_opts) or _usage();

_usage() unless defined $cmd_opts{p} and defined $cmd_opts{v};

=pod

=head1 EDITOR

The default editor used to minimize patches is meld.
A different editor can be set via the environment variable D4J_EDITOR.

=cut
my $EDITOR = $ENV{"D4J_EDITOR"} // "meld";

my $PID = $cmd_opts{p};
my $VID = $cmd_opts{v};
# Check format of target version id
$VID =~ /^(\d+)$/ or die "Wrong version id format: $VID -- expected: (\\d+)!";

my $patch_dir = "$SCRIPT_DIR/projects/$PID/patches";
my $src_patch = "$patch_dir/${VID}.src.patch";

my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");

# Set up project
my $project = Project::create_project($PID);
$project->{prog_root} = $TMP_DIR;

my $rev = $project->lookup("${VID}f");
my $src_path = $project->src_dir($rev);
$project->checkout_id("${VID}f");
$project->apply_patch($TMP_DIR, $src_patch, $src_path) == 0 or die;

# Minimize patch with configured editor
system("$EDITOR $TMP_DIR");

# Check whether patch could be successfully minimized
print "Patch minimized? [y/n] >";
my $input = <STDIN>; chomp $input;
exit 0 unless $input eq "y";

my $orig=`cd $TMP_DIR; git log | head -1 | cut -f2 -d' '`;
chomp $orig;
system("cd $TMP_DIR; git commit -a -m \"minimized patch\"");
my $min=`cd $TMP_DIR; git log | head -1 | cut -f2 -d' '`;
chomp $min;

# Last chance to reject patch
system("cd $TMP_DIR; git diff $orig:$src_path $min:$src_path");
print "Patch correct? [y/n] >";
$input = <STDIN>; chomp $input;
exit 0 unless $input eq "y";
system("cd $TMP_DIR; git diff $orig:$src_path $min:$src_path > $src_patch");

# Remove temporary directory
system("rm -rf $TMP_DIR");