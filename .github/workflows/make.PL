#!/usr/bin/env perl

use 5.006002;

use strict;
use warnings;

use Config;
use Getopt::Long 2.33 qw{ :config auto_version };
use Pod::Usage;

our $VERSION = '0.164';

my %opt;

GetOptions( \%opt,
    help => sub { pod2usage( { -verbose => 2 } ) },
) or pod2usage( { -verbose => 0 } );

exec { $Config{make} } $Config{make}, @ARGV;

__END__

=head1 TITLE

make.PL - Perl front end to *make

=head1 SYNOPSIS

 make.PL
 make.PL test
 make.PL --help
 make.PL --version

=head1 OPTIONS

=head2 --help

This option displays the documentation for this script. The script then
exits.

=head2 --version

This option displays the version of this script. The script then exits.

=head1 DETAILS

This Perl script simply does an C<exec()> of C<$Config{make}>, passing
it all its arguments.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
