package My::Module::Recommend::VersionOnly;

use 5.006002;

use strict;
use warnings;

use My::Module::Recommend::Any;
our @ISA = qw{ My::Module::Recommend::Any };

use Carp;
use Exporter qw{ import };

our $VERSION = '0.111';

our @EXPORT_OK = qw{ __version_only };

sub __version_only {
    my ( @args ) = @_;
    return __PACKAGE__->new( @args );
}

sub test_without {
    return;
}

1;

__END__

=head1 NAME

My::Module::Recommend::VersionOnly - Recommend unless a required module is less than a given version.

=head1 SYNOPSIS

 use My::Module::Recommend::VersionOnly qw{ __version_only };
 
 my $rec = __version_only( [ Fubar => 12345 ] => <<'EOD' );
       You might want to upgrade Fubar to at least version 12345 if you
       need to frozz a gaberbucket. If your gaberbucket does not need
       frozzing you do not need this module.
 EOD
 
 print $rec->recommend();

=head1 DESCRIPTION

This module is private to this package, and may be changed or retracted
without notice. Documentation is for the benefit of the author only.

This module checks whether the given module has at least the given
version; if not, it generates an explanatory message. We assume the
module is required -- or at least, we assume the user does not want to
hide the module when testing optional modules.

I am using this rather than the usual install tools' recommendation
machinery for greater flexibility, and because I personally have found
their output rather Draconian, and my correspondance indicates that my
users do too.

=head1 METHODS

This class is a subclass of C<My::Module::Recommend::Any>. It
supports the following methods which override those of the superclass.
These methods are private to this package and can be changed or
retracted without notice.

=head2 __version_only

 my $rec = __version_only( [ Foo => 12345 ] => "bar\n" );

This convenience subroutine (B<not> method) wraps L<new()|/new>. It is
not exported by default, but can be requested explicitly.

=head2 test_without

This override of the parent method returns nothing.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Tom Wyant (wyant at cpan dot org)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2020 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
