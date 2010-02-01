package Astro::Coord::ECI::Recommend;

use strict;
use warnings;

use Carp;
use Config;

sub recommend {
    my @recommend;
    foreach my $thing ( qw{ date_manip time_y2038 } ) {
	my $code = __PACKAGE__->can( "_recommend_$thing" ) or next;
	defined( my $recommendation = $code->() ) or next;
	push @recommend, $recommendation;
    }
    @recommend and warn <<'EOD', @recommend,

The following optional modules were not found:
EOD
    <<'EOD';
It is not necessary to install these now. If you decide to install them
later, this software will make use of them when it finds them.
EOD
    return;
}

sub _recommend_date_manip {
    eval { require Date::Manip; 1 } and return;
    my $recommendation = <<'EOD';
    * Date::Manip is not installed.
      This module is not required, but the alternative to installing it
      is to specify times to the 'satpass' script in ISO 8601 format.
      See 'SPECIFYING TIMES' in the 'satpass' documentation for the
      details.
EOD
    $] < 5.010 and $recommendation .= <<'EOD';
      Unfortunately, the current Date::Manip requires Perl 5.10. Since
      you are running an earlier Perl, you can try installing Date-Manip
      5.54, which is the most recent version that does _not_ require
      Perl 5.10.
EOD
    return $recommendation;
}

{

    my %misbehaving_os = map { $_ => 1 } qw{ MSWin32 cygwin };

    # NOTE WELL
    #
    # The description here must match the actual time module loading and
    # exporting logic in Astro::Coord::ECI::Utils.

    sub _recommend_time_y2038 {
	eval { require Time::y2038; 1 } and return;
	my $recommendation = <<'EOD';
    * Time::y2038 is not installed.
      This module is not required, but if installed allows you to do
      computations for times outside the usual range of system epoch to
      system epoch + 0x7FFFFFFF seconds.
EOD
	$misbehaving_os{$^O} and $recommendation .= <<"EOD";
      Unfortunately, Time::y2038 has been known to misbehave when
      running under $^O, so you may be better off just accepting the
      restricted time range.
EOD
	( $Config{use64bitint} || $Config{use64bitall} )
	    and $recommendation .= <<'EOD';
      Since your Perl appears to support 64-bit integers, you may well
      not need Time::y2038 to do computations for times outside the
      so-called 'usual range.' It will be used, though, if it is
      available.
EOD
	return $recommendation;
    }

}

1;

=head1 NAME

Astro::Coord::ECI::Recommend - Recommend modules to install. 

=head1 SYNOPSIS

 use lib qw{ inc };
 use Astro::Coord::ECI::Recommend;
 Astro::Coord::ECI::Recommend->recommend();

=head1 DETAILS

This package generates the recommendations for optional modules. It is
intended to be called by the build system. The build system's own
mechanism is not used because we find its output on the Draconian side.

=head1 METHODS

This class supports the following public methods:

=head2 recommend

 Astro::Coord::ECI::Recommend->recommend();

This static method examines the current Perl to see which optional
modules are installed. If any are not installed, a message is printed to
standard out explaining the benefits to be gained from installing the
module, and any possible problems with installing it.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
