#!/usr/bin/env perl
#
# Install Git LFS on Windows
#
use strict;
use warnings;
use File::Spec;
use IO::Uncompress::Unzip qw(unzip $UnzipError);

die("usage: $0 LFSZIPFILE PATHTOGITEXE") if scalar(@ARGV) < 2;
my $zipfile = $ARGV[0];
my $path    = $ARGV[1];

my $foundname = '';
my $z         = new IO::Uncompress::Unzip $zipfile
  or die("Could not scan zip archive: $UnzipError");
{
    do {
        my $currentname = $z->getHeaderInfo()->{'Name'};
        my ( $x, $y, $basename ) = File::Spec->splitpath("$currentname");
        if ( 'git-lfs.exe' eq $basename ) {
            $foundname = $currentname;
            last;
        }
      } while ( $z->nextStream() )
}
$z->close();

die('Could not find a git-lfs executable in specified archive')
  unless $foundname;

my @parts = File::Spec->splitdir($path);

while (@parts) {
    for my $sub ( 'cmd', 'bin' ) {
        my $testdir = File::Spec->catdir( @parts, $sub );
        my $vol;
        my $testpath = File::Spec->catpath( $vol, $testdir, 'git.exe' );

        if ( -e $testpath ) {
            print "File exists: $testpath\n";
            my $outfile = File::Spec->catpath( $vol, $testdir, 'git-lfs.exe' );
            print "unzip $zipfile => $outfile, Name => \"$foundname\"\n";
            unzip $zipfile => $outfile,
              Name         => "$foundname"
              or die("Error extracting Git-LFS: $UnzipError");
        }
    }
    pop @parts;
}
