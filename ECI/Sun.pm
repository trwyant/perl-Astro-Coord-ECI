=head1 NAME

Astro::Coord::ECI::Sun - Compute the position of the Sun.

=head1 SYNOPSIS

 my $sun = Astro::Coord::ECI::Sun->new ();
 my $sta = Astro::Coord::ECI->
     universal (time ())->
     geodetic ($lat, $long, $alt);
 my ($time, $rise) = $sta->next_elevation ($sun);
 print "Sun @{[$rise ? 'rise' : 'set']} is ",
     scalar localtime $time;

=head1 DESCRIPTION

This module implements the position of the Sun as a function of time,
as described in Jean Meeus' "Astronomical Algorithms," second edition.
It is a subclass of Astro::Coord::ECI, with the id, name, and diameter
attributes initialized appropriately, and the time_set() method
overridden to compute the position of the Sun at the given time.


=head2 Methods

The following methods should be considered public:

=over

=cut

use strict;
use warnings;

package Astro::Coord::ECI::Sun;

our $VERSION = 0.001;

use base qw{Astro::Coord::ECI};

use Carp;
use Data::Dumper;
use POSIX qw{floor strftime};
##use Time::Local;
use UNIVERSAL qw{isa};

use constant ASTRONOMICAL_UNIT => 149_597_870;	# Meeus, Appendix I, page 407.

#	"Hand-import" non-oo utilities from the superclass.

BEGIN {
*_deg2rad = \&Astro::Coord::ECI::_deg2rad;
*_mod2pi = \&Astro::Coord::ECI::_mod2pi;
*PIOVER2 = \&Astro::Coord::ECI::PIOVER2;
*_rad2deg = \&Astro::Coord::ECI::_rad2deg;
}

my %static = (
    id => 'Sun',
    name => 'Sun',
    diameter => 1392000,
    );

=item $sun = Astro::Coord::ECI::Sun->new ();

This method instantiates an object to represent the coordinates of the
Sun. This is a subclass of Astro::Coord::ECI, with the id and name
attributes set to 'Sun', and the diameter attribute set to 1392000 km
per Jean Meeus' "Astronomical Algorithms", 2nd Edition, Appendix I,
page 407.

Any arguments are passed to the set() method once the object has been
instantiated. Yes, you can override the "hard-wired" id, name, and so
forth in this way.

=cut

sub new {
my $class = shift;
my $self = $class->SUPER::new (%static, @_);
}


=item @almanac = $sun->almanac ($location, $start, $end);

This method produces almanac data for the Sun for the given location,
between the given start and end times. The location is assumed to be
Earth-Fixed - that is, you can't do this for something in orbit.

The start time defaults to the current time setting of the $sun
object, and the end time defaults to a day after the start time.

The almanac data consists of a list of list references. Each list
reference points to a list containing the following elements:

 [0] => time
 [1] => event (string)
 [2] => detail (integer)
 [3] => description (string)

The @almanac list is returned sorted by time.

The following events, details, and descriptions are at least
potentially returned:

 horizon: 0 = Sunset, 1 = Sunrise;
 transit: 0 = local midnight, 1 = local noon;
 twilight: 0 = end twilight, 1 = begin twilight;
 quarter: 0 = spring equinox, 1 = summer solstice,
          2 = fall equinox, 3 = winter solstice.

Twilight is calculated based on the current value of the twilight
attribute of the $sun object.

=cut

my @quarters = ('Spring equinox', 'Summer solstice', 'Fall equinox',
	'Winter solstice');

sub almanac {
my $self = shift;
my $location = shift;
ref $location && UNIVERSAL::isa ($location, 'Astro::Coord::ECI') or
    croak <<eod;
Error - The first argument of the almanac() method must be a member of
        the Astro::Coord::ECI class, or a subclass thereof.
eod

my $start = shift || $self->universal;
my $end = shift || $start + 86400;

my @almanac;

foreach (
	[$location, next_elevation => [$self, 0, 1], 'horizon',
		['Sunset', 'Sunrise']],
	[$location, next_meridian => [$self], 'transit',
		['local midnight', 'local noon']],
	[$location, next_elevation => [$self, $self->get ('twilight'), 0], 'twilight',
		['end twilight', 'begin twilight']],
	[$self, next_quarter => [], 'quarter',
		[@quarters]],
	) {
    my ($obj, $method, $arg, $event, $descr) = @$_;
    $obj->universal ($start);
    while (1) {
	my ($time, $which) = $obj->$method (@$arg);
	last if $time >= $end;
	push @almanac, [$time, $event, $which, $descr->[$which]]
	    if $descr->[$which];
	}
    }
return sort {$a->[0] <=> $b->[0]} @almanac;
}


=item $longitude = $sun->ecliptic_longitude ();

This method returns the ecliptic longitude of the sun at its current
time setting, in radians. It's really just a convenience method, since
it is equivalent to ($sun->ecliptic)[1], and in fact that is how it is
implemented.

=cut

sub ecliptic_longitude {
my $self = shift;
($self->ecliptic ())[1];
}


=item $long = $sun->geometric_longitude()

This method returns the geometric longitude of the Sun in radians at
the last time set.

=cut

sub geometric_longitude {
my $self = shift;
croak <<eod unless defined $self->{_sun_geometric_longitude};
Error - You must set the time of the Sun object before the geometric
        longitude can be returned.
eod

$self->{_sun_geometric_longitude};
}


=item ($time, $quarter) = $sun->next_quarter ($want);

This method calculates the time of the next equinox or solstice
after the current time setting of the $sun object. The return is the
time, and which equinox or solstice it is, as a number from 0 (vernal
equinox) to 3 (winter solstice). If called in scalar context, you just
get the time.

The optional $want argument says which equinox or solstice you want.

As a side effect, the time of the $sun object ends up set to the
returned time.

The method of calculation is successive approximation, and actually
returns the second b<after> the calculated equinox or solstice.

Since we only calculate the Sun's position to the nearest 0.01 degree,
the calculated solstice or equinox may be in error by as much as 15
minutes.

=cut

use constant QUARTER_INC => 86400 * 85;	# 85 days.

sub next_quarter {
my $self = shift;
my $quarter = (defined $_[0] ? shift :
    floor ($self->ecliptic_longitude () / PIOVER2) + 1) % 4;
my $begin;
while (floor ($self->ecliptic_longitude () / PIOVER2) == $quarter) {
    $begin = $self->dynamical;
    $self->dynamical ($begin + QUARTER_INC);
    }
while (floor ($self->ecliptic_longitude () / PIOVER2) != $quarter) {
    $begin = $self->dynamical;
    $self->dynamical ($begin + QUARTER_INC);
    }
my $end = $self->dynamical ();

while ($end - $begin > 1) {
    my $mid = floor (($begin + $end) / 2);
    my $qq = floor ($self->dynamical ($mid)->ecliptic_longitude () / PIOVER2);
    ($begin, $end) = $qq == $quarter ?
	($begin, $mid) : ($mid, $end);
    }

$self->dynamical ($end);

wantarray ? ($self->universal, $quarter, $quarters[$quarter]) : $self->universal;
}


=item $period = $sun->period ()

Although this method is attached to an object that represents the
Sun, what it actually returns is the siderial period of the Earth,
per Appendix I (pg 408) of Jean Meeus' "Astronomical Algorithms,"
2nd edition.

=cut

sub period {31558149.7632}	# 365.256363 * 86400


use constant OBLIQUITY_CORRECTION => _deg2rad (0.00256);

=item $radians = $self->obliquity_correction ($omega);

This method calculates the correction to the obliquity in terms of the
given dynamical time.

Jean Meeus' "Astronomical Algorithms," 2nd Edition, page 165 states
that for calculating the apparent position of the Sun we need to add
0.00256 degrees * cos (omega) to the obliquity. This method overrides
the base class' method to accomplish this.

sub obliquity_correction {cos ($_[0]->omega ($_[1]) * OBLIQUITY_CORRECTION)}


=item $sun->time_set ()

This method sets coordinates of the object to the coordinates of the
Sun at the object's currently-set universal time.  The velocity
components are arbitrarily set to 0.

Although there's no reason this method can't be called directly, it
exists to take advantage of the hook in the Astro::Coord::ECI
object, to allow the position of the Sun to be computed when the
object's time is set.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 25, pages 163ff.

=cut

#	The following constants are used in the time_set() method,
#	because Meeus' equations are in degrees, I was too lazy
#	to hand-convert them to radians, but I didn't want to
#	penalize the user for the conversion every time.


use constant SUN_C1_0 => _deg2rad (1.914602);
use constant SUN_C1_1 => _deg2rad (-0.004817);
use constant SUN_C1_2 => _deg2rad (-0.000014);
use constant SUN_C2_0 => _deg2rad (0.019993);
use constant SUN_C2_1 => _deg2rad (0.000101);
use constant SUN_C3_0 => _deg2rad (0.000289);
use constant SUN_LON_2000 => _deg2rad (- 0.01397);

sub time_set {
my $self = shift;

my $time = $self->dynamical;


#	The following algorithm is from Meeus, chapter 25, page, 163 ff.

my $T = $self->jcent2000 ($time);				# Meeus (25.1)
my $L0 = _mod2pi (_deg2rad ((.0003032 * $T + 36000.76983) * $T	# Meeus (25.2)
	+ 280.46646));
my $M = _mod2pi (_deg2rad (((-.0001537) * $T + 35999.05029)	# Meeus (25.3)
	* $T + 357.52911));
my $e = (-0.0000001267 * $T - 0.000042037) * $T + 0.016708634;	# Meeus (25.4)
my $C  = ((SUN_C1_2 * $T + SUN_C1_1) * $T + SUN_C1_0) * sin ($M)
	+ (SUN_C2_1 * $T + SUN_C2_0) * sin (2 * $M)
	+ SUN_C3_0 * sin (3 * $M);
my $O = $self->{_sun_geometric_longitude} = $L0 + $C;
my $omega = _mod2pi (_deg2rad (125.04 - 1934.156 * $T));
my $lamda = _mod2pi ($O - _deg2rad (0.00569 + 0.00478 * sin ($omega)));
my $nu = $M + $C;
my $R = (1.000_001_018 * (1 - $e * $e)) / (1 + $e * cos ($nu))
	* ASTRONOMICAL_UNIT;
$self->{debug} and print <<eod;
Debug sun - @{[strftime '%d-%b-%Y %H:%M:%S', gmtime $time]}
    T  = $T
    L0 = @{[_rad2deg ($L0)]} degrees
    M  = @{[_rad2deg ($M)]} degrees
    e  = $e
    C  = @{[_rad2deg ($C)]} degrees
    O  = @{[_rad2deg ($O)]} degrees
    R  = @{[$R / ASTRONOMICAL_UNIT]} AU
    omega = @{[_rad2deg ($omega)]} degrees
    lamda = @{[_rad2deg ($lamda)]} degrees
eod

$self->ecliptic (0, $lamda, $R);
}

1;

=back

=head1 ACKNOWLEDGEMENTS

The author wishes to acknowledge the following individuals and
organizations.

Jean Meeus, whose book "Astronomical Algorithms" (second edition)
formed the basis for this module.

Dr. Meeus' publisher, Willman-Bell Inc (F<http://www.willbell.com/>),
which kindly granted permission to use Dr. Meeus' work in this module.

=head1 SEE ALSO

The B<Astro-MoonPhase> package by Brett Hamilton, which contains a
function-based module to compute the current phase, distance and
angular diameter of the Moon, as well as the angular diameter and
distance of the Sun.

The B<Astro-Sunrise> package by Ron Hill, which contains a function-based
module to compute sunrise and sunset for the given day and location.

The B<Astro-SunTime> package by Rob Fugina, which provides functionality
similar to B<Astro-Sunrise>.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2005 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself.

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
