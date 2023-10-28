#!/usr/bin/env perl

use 5.006002;

use strict;
use warnings;

use Config;
use File::Spec;
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
    my $my_home = $is_windows ?
        __PACKAGE__->my_home_windows() :
        __PACKAGE__->my_home_unix();
    my %env = (
        MY_HOME             => $my_home,
        MY_IS_GITHUB_ACTION => 1,
        MY_IS_UNIX          => $is_unix,
        MY_IS_WINDOWS       => $is_windows,
        MY_MAKE             => $Config{make},
        MY_WANT_POD_MAN     => want_pod_man(),
    );

    $is_windows
        and @env{ qw{ LINES COLUMNS } } = ( 24, 80 );

    return \%env;
}

# BEGIN Stolen shamelessly from File::HomeDir::Windows

sub my_home_windows
{
    my $class = shift;

    # A lot of unix people and unix-derived tools rely on
    # the ability to overload HOME. We will support it too
    # so that they can replace raw HOME calls with File::HomeDir.
    if (exists $ENV{HOME} and defined $ENV{HOME} and length $ENV{HOME})
    {
        return $ENV{HOME};
    }

    # Do we have a user profile?
    if (exists $ENV{USERPROFILE} and $ENV{USERPROFILE})
    {
        return $ENV{USERPROFILE};
    }

    # Some Windows use something like $ENV{HOME}
    if (exists $ENV{HOMEDRIVE} and exists $ENV{HOMEPATH} and $ENV{HOMEDRIVE} and $ENV{HOMEPATH})
    {
        return File::Spec->catpath($ENV{HOMEDRIVE}, $ENV{HOMEPATH}, '',);
    }

    return undef;
}

sub my_home_unix
{
    my $class = shift;
    my $home  = $class->_guess_home(@_);

    # On Unix in general, a non-existent home means "no home"
    # For example, "nobody"-like users might use /nonexistent
    if (defined $home and not -d $home)
    {
        $home = undef;
    }

    return $home;
}

sub _guess_env_home
{
    my $class = shift;
    if (exists $ENV{HOME} and defined $ENV{HOME} and length $ENV{HOME})
    {
        return $ENV{HOME};
    }

    # This is from the original code, but I'm guessing
    # it means "login directory" and exists on some Unixes.
    if (exists $ENV{LOGDIR} and $ENV{LOGDIR})
    {
        return $ENV{LOGDIR};
    }

    return;
}

sub _guess_determined_home
{
    my $class = shift;

    # Light desperation on any (Unixish) platform
  SCOPE:
    {
        my $home = (getpwuid($<))[7];
        return $home if $home and -d $home;
    }

    return;
}

sub _guess_home
{
    my $class = shift;
    my $home  = $class->_guess_env_home($@);
    $home ||= $class->_guess_determined_home($@);
    return $home;
}

# END Stolen shamelessly from File::HomeDir::Windows

sub want_pod_man {
    my ( $perl_ver ) = @_;
    defined $perl_ver
        or $perl_ver = THIS_PERL;

    # NOTE that if we need to play this game with higher versions of
    # Perl, the github-actions script needs to be modified too,
    $perl_ver < PERL_5_10
        and return 'RRA/podlators-4.14.tar.gz';
    $perl_ver < PERL_5_12
        and return 'Pod::Man';
    return '';
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

The job's home directory, as determined by internal code stolen
shamelessly from L<File::HomeDir|File::HomeDir>.

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

=head2 MY_WANT_POD_MAN

The specification of the C<podlators> distribution to install.
Empty if the version that comes with the running Perl is OK. This
is needed because Module::Build requires it.

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
