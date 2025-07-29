#!/usr/bin/env perl

use 5.006002;

use strict;
use warnings;

use Config;

our $VERSION = '2.000';

use constant THIS_PERL  => "$]";

unless ( caller ) {
    my $env_hash = compute_environment();

    my $env_text;
    $env_text .= "$_=$env_hash->{$_}\n" for sort keys %{ $env_hash };

    if ( defined( $ENV{GITHUB_ENV} ) && $ENV{GITHUB_ENV} ne '' ) {
        open my $fh, '>>:encoding(utf-8)', $ENV{GITHUB_ENV}
            or die "Can not open $ENV{GITHUB_ENV}: $!\n";
        print { $fh } $env_text;
        close $fh;
    } else {
        print $env_text;
        die "Environment variable GITHUB_ENV undefined or empty\n";
    }
}

sub compute_environment {
    my $is_windows = {
        MSWin32     => 1,
        dos         => 1,
    }->{$^O} || '';
    my %env = (
        MY_MAKE             => $Config{make},
        MY_WANT_MODULES     => join( ' ', want_modules() ),
    );

    $is_windows
        and @env{ qw{ LINES COLUMNS } } = ( 24, 80 );

    return \%env;
}

# NOTE that we rely on the templating system's perl::Type module to
# compute recursive dependencies to figure out which possibly-indirect
# dependencies we need to handle under old Perls.
sub want_modules {
    my ( $perl_ver ) = @_;
    defined $perl_ver
        or $perl_ver = THIS_PERL;
    foreach (
	[ qw{ 5.012000  } ],
	[ qw{ 5.010001 Pod::Text@4.14 } ],
	[ qw{ 5.000000 Pod::Text@4.14 XSLoader@0.10 } ],
    ) {
        my ( $version, @want ) = @{ $_ };
        $perl_ver >= $version
            and return @want;
    }
    die "Bug - Unsupported perl version $]";
}

1;

__END__

=head1 TITLE

environment.PL - Customize GitHub Actions environment

=head1 SYNOPSIS

 .github/workflows/environment.PL

=head1 OPTIONS

None.

=head1 DETAILS

This Perl script adds environment variables to the GitHub Actions
environment. The following environment variables are added:

=head2 COLUMNS

Windows only. C<'80'>.

=head2 LINES

Windows only. C<'24'>.

=head2 MY_MAKE

The value of C<$Config{make}>.

=head2 MY_WANT_MODUKES

A space-delimited list of modules or repositories to install B<before>
installing dependencies. This is computed in an admittedly ad-hoc manner
based on the version of Perl being used, and is intended to cover the
case where old Perls (typically before C<5.10> can not execute the
current version of a module.

=head1 INVOCATION AS MODULINO

This script can also be used (or required) as a modulino. When you do
this, the following subroutines get loaded into C<main::>:

=head2 compute_environment

This subroutine takes no arguments. It returns a reference to a hash
that describes the environment variables to be added to the environment.

=head2 want_modules

This subroutine takes an optional Perl version, and returns a list of
modules or distributions to be installed that version B<before> module
prerequisites are processed. If no argument is provided, the version of
the currently-running Perl is assumed.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set ts=8 sts=4 sw=4 tw=72 ft=perl expandtab shiftround :
