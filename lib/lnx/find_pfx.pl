#!/usr/bin/env perl

# We don't want the plumbing directory.
# We would like to see what the user would when
# typing `which git`

use strict;
use warnings;
use File::Basename;

for my $dir ( split( /:/, $ENV{'PATH'} ) ) {
    next if ( $dir =~ /git-core/ );
    if ( -f "$dir/git" ) {
        print "$dir\n";
        exit(0);
    }
}
die "git not found in " . $ENV{'PATH'} . "\n";
