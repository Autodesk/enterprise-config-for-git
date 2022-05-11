#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;
use Getopt::Long;
use JSON::PP;
use Pod::Usage;
use File::Basename;
use File::Temp qw /tempfile/;

my %options;
GetOptions(
    \%options,   "--description=s", "--help",    "--name=s",
    "--verbose", "--user=s",        "--token=s", "--server=s",
    "--private"
) or pod2usage( "Try '$0 --help' for more information.", -exitval => 1 );

run( \%options, @ARGV );

exit(0);

sub slurp {
    my ($file) = @_;
    my $contents = do { local ( @ARGV, $/ ) = $file; <> };
    return $contents;
}

sub run {
    my ( $opts, @args ) = @_;

    if ( $opts->{help} ) {
        pod2usage( -verbose => 1 );
    }

    my $files = collect_files( $opts, @args );
    my $uri = post( $opts, $files );
    say $uri;
}

sub collect_files {
    my ( $opts, @args ) = @_;

    my $files = {};
    if ( @args == 0 or $args[0] eq '-' ) {
        my $content = join '', <STDIN>;
        $files->{ $opts->{name} || '' } = { content => $content };
    }
    else {
        for my $arg (@args) {
            my $name = basename($arg);
            $files->{$name} = { content => slurp($arg), };
        }
    }

    return $files;
}

sub post {
    my ( $opts, $files ) = @_;
    my $url =
        "https://"
      . $opts->{user} . ":"
      . $opts->{token} . '@'
      . $opts->{server}
      . "/api/v3/gists";

    say $url if ( $opts->{verbose} );

    my $data = { files => $files, };

    if ( defined( $opts->{description} ) ) {
        $data->{"description"} = $opts->{description};
    }

    if ( defined( $opts->{private} ) ) {
        $data->{"public"} = JSON::PP::false;
    }
    else {
        $data->{"public"} = JSON::PP::true;
    }

    my $json = encode_json($data);
    say $json if ( $opts->{verbose} );

    my ( $fh, $filename ) =
      tempfile( "git-adsk-gist-XXXXX", TMPDIR => 1, UNLINK => 1 );

    print $fh $json;

    my $cmd = "curl --silent -d \@$filename \"$url\"";
    say $cmd if ( $opts->{verbose} );
    my $response = `$cmd`;
    say $response if ( $opts->{verbose} );
    my $content = decode_json($response);
    if ( exists( $content->{html_url} ) ) {
        return $content->{html_url};
    }
    else {
        pod2usage("Invalid request provoked this response: \n\n$response\n");
    }
}

__END__

=head1 NAME

paste.pl - Uploads files to GitHub's gist service

=head1 SYNOPSIS

  git emc paste something.c
  echo foo | git emc paste
  git emc paste --private not_ready_for_primetime.c

=head1 DESCRIPTION

Upload a file to GitHub's gist service

=head1 SEE ALSO

=over 4

=item *
inspiration from L<https://github.com/miyagawa/gistp>

=back

=cut
