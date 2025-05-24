#!/usr/bin/env perl

use 5.006002;

use strict;
use warnings;

use Getopt::Long;
use version;

use constant THIS_PERL  => version->parse( $] );
use constant PERL_5_10  => version->parse( 'v5.10.0' );
use constant PERL_5_12  => version->parse( 'v5.12.0' );

unless ( caller ) {
    my %opt;

    GetOptions( \%opt,
        qw{ verbose },
    ) or die "Bad option\n";


    my $env_hash = compute_environment();

    my $env_text;
    $env_text .= "$_=$env_hash->{$_}\n" for sort keys %{ $env_hash };

    $opt{verbose} and print $env_text;

    defined $ENV{GITHUB_ENV}
        and $ENV{GITHUB_ENV} ne ''
        or die "Environment variable GITHUB_ENV undefined or empty\n";
    open my $fh, '>>:encoding(utf-8)', $ENV{GITHUB_ENV}
        or die "Can not open $ENV{GITHUB_ENV}: $!\n";

    print { $fh } $env_text;

    close $fh;
}

sub compute_environment {
    my $is_windows = {
        MSWin32     => 1,
        dos         => 1,
    }->{$^O} || '';
    my $is_unix = $is_windows ? '' : 1;
    my $my_home;
    {
        local $@ = undef;
        eval {
            require File::HomeDir;
            $my_home = File::HomeDir->my_home();
            print "Home from File::HomeDir\n";
            1;
        } or do {
            $my_home = $ENV{HOME};
            print "Home from \$HOME\n";
        };
    }
    my @want_modules = want_modules();
    my %env = (
        MY_HOME             => $my_home,
        MY_IS_GITHUB_ACTION => 1,
        MY_IS_UNIX          => $is_unix,
        MY_IS_WINDOWS       => $is_windows,
        MY_WANT_MODULES     => "@want_modules",
    );

    $is_windows
        and @env{ qw{ LINES COLUMNS } } = ( 24, 80 );

    return \%env;
}

# FIXME Not all my distros need HTML-Tagset. Figure out a way to handle
# this other than by bashing this script. This is not straightforward
# because HTML-Tagset is probably not a direct dependency.
sub want_modules {
    my ( $perl_ver ) = @_;
    defined $perl_ver
        or $perl_ver = THIS_PERL;
    if ( $perl_ver >= PERL_5_12 ) {
        return;
    } elsif ( $perl_ver >= PERL_5_10 ) {
        return qw{
            RRA/podlators-4.14.tar.gz
        };
    } else {
        return qw{
            SMUELLER/ExtUtils-ParseXS-3.30.tar.gz
            RRA/podlators-4.14.tar.gz
        };
    }
}

1;

__END__

=head1 TITLE

environment.PL - Customize GitHub Actions environment

=head1 SYNOPSIS

 .github/workflows/environment.PL
 .github/workflows/environment.PL --verbose

=head1 OPTIONS

=head2 --verbose

If this Boolean option is asserted, the environment variables defiend
are written to standard output.

The default is C<--no-verbose>.

=head1 DETAILS

This Perl script adds environment variables to the GitHub Actions
environment. The following environment variables are added:

=head2 MY_HOME

The job's home directory, as determined by
L<File::HomeDir|File::HomeDir>.

=head2 MY_IS_GITHUB_ACTION

Always true (i.e. C<'1'>).

=head2 MY_IS_UNIX

True (i.e. C<1>) if running under some flavor of Unix, and false (i.e.
C<''>) otherwise. At the moment this is the Boolean inverse of
L<MY_IS_WINDOWS|/MY_IS_WINDOWS>.

=head2 MY_IS_WINDOWS

True (i.e. C<1>) if running under Windows, and false (i.e. C<''>)
othewise. At the moment this is true if C<$^O> is C<'MSWin32'> or
C<'dos'>.

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

This subroutine takes an optional L<version|version> object representing
a Perl version, and returns a list of modules or distributions to be
installed that version B<before> module prerequisites are
processed. If no argument is provided, the version of the
currently-running Perl is assumed.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set ts=8 sts=4 sw=4 tw=72 ft=perl expandtab shiftround :
