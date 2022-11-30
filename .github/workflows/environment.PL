use strict;
use warnings;

use File::HomeDir;

open my $fh, '>>:encoding(utf-8)', $ENV{GITHUB_ENV}
    or die "Can not open $ENV{GITHUB_ENV}: $!\n";

my $home = File::HomeDir->my_home();
my $is_5_10 = "$]" >= 5.010 ? 1 : '';
my $is_windows = {
    MSWin32	=> 1,
    dos		=> 1,
}->{$^O} || '';
my $is_unix = $is_windows ? '' : 1;
my $shell = defined $ENV{SHELL} ? $ENV{SHELL} : 'unknown';

print $fh <<"EOD";
MY_HOME=$home
MY_IS_UNIX=$is_unix
MY_IS_WINDOWS=$is_windows
MY_PERL_IS_5_10=$is_5_10
EOD

__END__

=head1 TITLE

environment.PL - Customize GitHub Actions environment

=head1 SYNOPSIS

 .github/workflows/environment.PL

=head1 DETAILS

This Perl script adds environment variables to the GitHub Actions
environment. The following environment variables are added:

=head2 MY_HOME

The job's home directory, as determined by
L<File::HomeDir|File::HomeDir>.

=head2 MY_IS_UNIX

True (i.e. C<1>) if running under some flavor of Unix, and false (i.e.
C<''>) otherwise. At the moment this is the Boolean inverse of
L<MY_IS_WINDOWS|/MY_IS_WINDOWS>.

=head2 MY_IS_WINDOWS

True (i.e. C<1>) if running under Windows, and false (i.e. C<''>)
othewise. At the moment this is true if C<$^O> is C<'MSWin32'> or
C<'dos'>.

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

# ex: set textwidth=72 :
