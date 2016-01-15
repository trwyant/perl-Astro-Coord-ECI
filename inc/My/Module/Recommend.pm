package My::Module::Recommend;

use strict;
use warnings;

use Carp;
use Config;

sub recommend {
    my @recommend;
    my $pkg_hash = __PACKAGE__ . '::';
    no strict qw{ refs };
    foreach my $subroutine ( sort keys %$pkg_hash ) {
	$subroutine =~ m/ \A _recommend_ \w+ \z /smx or next;
	my $code = __PACKAGE__->can( $subroutine ) or next;
	defined( my $recommendation = $code->() ) or next;
	push @recommend, "\n" . $recommendation;
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

sub _recommend_astro_simbad_client {
    local $@ = undef;
    eval { require Astro::SIMBAD::Client; 1 } and return;
    return <<'EOD';
    * Astro::SIMBAD::Client is not installed.
      This module is required for the 'satpass' script's 'sky lookup'
      command, but is otherwise unused by this package. If you do not
      intend to use this functionality, Astro::SIMBAD::Client is not
      needed.
EOD
}

sub _recommend_astro_spacetrack {
    local $@ = undef;
    eval {
	require Astro::SpaceTrack;
	Astro::SpaceTrack->VERSION( 0.052 );
	1;
    } and return;
    return <<'EOD';
    * Astro::SpaceTrack version 0.052 or higher is not installed.
      This module is required for the 'satpass' script's 'st' command,
      but is otherwise unused by this package. If you do not intend to
      use this functionality, Astro::SpaceTrack is not needed.
EOD
}

sub _recommend_date_manip {
    local $@ = undef;
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

sub _recommend_datetime {
    local $@ = undef;
    eval { require DateTime; require DateTime::TimeZone; 1; }
	and return;
    return <<'EOD';
    * DateTime and/or DateTime::TimeZone are not installed.
      If you set the 'zone' attribute of My::Module::TLE::Iridium
      to a zone name, these modules will be used to determine if a flare
      occurred before or after midnight. If not available, $ENV{TZ} will
      be set to the zone name in the hope that the localtime() built-in
      will respond to this. If the 'zone' attribute is undef (the
      default) or a numeric offset from GMT, this module is not used.
EOD
}

sub _recommend_geo_coder_geocoder_us {
    local $@ = undef;
    eval { require Geo::Coder::Geocoder::US; 1 } and return;
    my $recommendation = <<'EOD';
    * Geo::Coder::Geocoder::US is not installed.
      This module is required for the 'satpass' script's 'geocode'
      command, but is otherwise unused by this package. If you do not
      intend to use this functionality, this package is not needed.
EOD
    return $recommendation;
}

sub _recommend_geo_webservice_elevation_usgs {
    local $@ = undef;
    eval { require Geo::WebService::Elevation::USGS; 1 } and return;
    return <<'EOD';
    * Geo::WebService::Elevation::USGS is not installed.
      This module is required for the 'satpass' script's 'height'
      command, but is otherwise unused by this package. If you do not
      intend to use this functionality, Geo::WebService::Elevation::USGS
      is not needed.
EOD
}

sub _recommend_io_string {
    local $@ = undef;
    $] >= 5.008 and $Config{useperlio} and return;
    eval { require IO::String; 1 } and return;
    return <<'EOD';
    * IO::String is not installed.
      You appear to have a version of Perl earlier than 5.8, or one
      which is not configured to use perlio. Under this version of Perl
      IO::String is required by the 'satpass' script if you wish to pass
      commands on the command line, or to define macros. If you do not
      intend to do these things, IO::String is not needed.
EOD
}

sub _recommend_json {
    local $@ = undef;
    eval { require JSON; 1 } and return;
    return <<'EOD';
    * JSON is not installed, or can not be loaded.
      You need the JSON module only if you intend to pass JSON orbital
      data obtained from Space Track to the My::Module::TLE
      parse() method.
EOD
}

{

    my %misbehaving_os = map { $_ => 1 } qw{ MSWin32 cygwin };

    # NOTE WELL
    #
    # The description here must match the actual time module loading and
    # exporting logic in My::Module::Utils.

    sub _recommend_time_y2038 {
	eval $] >= 5.012 and return;
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

My::Module::Recommend - Recommend modules to install. 

=head1 SYNOPSIS

 use lib qw{ inc };
 use My::Module::Recommend;
 My::Module::Recommend->recommend();

=head1 DETAILS

This package generates the recommendations for optional modules. It is
intended to be called by the build system. The build system's own
mechanism is not used because we find its output on the Draconian side.

=head1 METHODS

This class supports the following public methods:

=head2 recommend

 My::Module::Recommend->recommend();

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

Copyright (C) 2010-2016 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

__END__

# ex: set textwidth=72 :
