#!/usr/bin/env perl
#
# Install Git LFS on Windows
#
use File::Spec;
use IO::Uncompress::Unzip qw(unzip $UnzipError);

die("usage: $0 LFSZIPFILE PATHTOGITEXE") if scalar(@ARGV) < 2;
$zipfile = $ARGV[0];
$path = $ARGV[1];

@parts = File::Spec->splitdir($path);

while (@parts) {
    foreach $sub ('cmd', 'bin') {
        $testdir = File::Spec->catdir(@parts, $sub);
        $testpath = File::Spec->catpath($vol, $testdir, 'git.exe');

        if (-e $testpath) {
            print "File exists: $testpath\n";
            $outfile = File::Spec->catpath($vol, $testdir, 'git-lfs.exe');
            print "unzip $zipfile => $outfile, Name => \"git-lfs.exe\"\n";
            unzip $zipfile => $outfile, Name => "git-lfs.exe" or
                die("Error extracting Git-LFS.");
        }
    }
    pop @parts;
}
