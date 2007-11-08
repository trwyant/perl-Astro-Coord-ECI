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

This module implements the position of the Sun as a function of time, as
described in Jean Meeus' "Astronomical Algorithms," second edition. It
is a subclass of B<Astro::Coord::ECI>, with the id, name, and diameter
attributes initialized appropriately, and the time_set() method
overridden to compute the position of the Sun at the given time.


=head2 Methods

The following methods should be considered public:

=over

=cut

use strict;
use warnings;

package Astro::Coord::ECI::Sun;

our $VERSION = '0.005_04';

use base qw{Astro::Coord::ECI};

use Astro::Coord::ECI::Utils qw{:all};
use Carp;
## use Data::Dumper;
use POSIX qw{floor strftime};
use UNIVERSAL qw{isa};

my %static = (
    id => 'Sun',
    name => 'Sun',
    diameter => 1392000,
    );

my $weaken = eval {
    require Scalar::Util;
    UNIVERSAL::can ('Scalar::Util', 'weaken');
    };
my $object;

our $Singleton = $weaken;

=item $sun = Astro::Coord::ECI::Sun->new();

This method instantiates an object to represent the coordinates of the
Sun. This is a subclass of B<Astro::Coord::ECI>, with the id and name
attributes set to 'Sun', and the diameter attribute set to 1392000 km
per Jean Meeus' "Astronomical Algorithms", 2nd Edition, Appendix I,
page 407.

Any arguments are passed to the set() method once the object has been
instantiated. Yes, you can override the "hard-wired" id, name, and so
forth in this way.

If $Astro::Coord::ECI::Sun::Singleton is true, you get a singleton
object; that is, only one object is instantiated and subsequent calls
to new() just return that object. This only works if Scalar::Util
exports weaken(). If it does not, the setting of
$Astro::Coord::ECI::Sun::Singleton is silently ignored. The default
is true if Scalar::Util can be loaded and exports weaken(), and false
otherwise.

=cut

sub new {
my $class = shift;
if ($Singleton && $weaken && UNIVERSAL::isa ($class, __PACKAGE__)) {
    if ($object) {
	$object->set (@_) if @_;
	return $object;
	}
      else {
	my $self = $object = $class->SUPER::new (%static, @_);
	$weaken->($object);
	return $self;
	}
    }
  else {
    $class->SUPER::new (%static, @_);
    }
}


=item @almanac = $sun->almanac($location, $start, $end);

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
	[$location, next_elevation => [$self, $self->get ('twilight'), 0],
		'twilight', ['end twilight', 'begin twilight']],
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
time setting, in radians. It is really just a convenience method, since
it is equivalent to ($sun->ecliptic)[1], and in fact that is how it is
implemented.

=cut

sub ecliptic_longitude {
my $self = shift;
($self->ecliptic ())[1];
}


=item $long = $sun->geometric_longitude ()

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


=item ($point, $intens, $central) = magnitude ($theta, $omega);

This method returns the magnitude of the Sun at a point $theta radians
from the center of its disk, given that the disk's angular radius
(B<not> diameter) is $omega radians. The returned $point is the
magnitude at the given point (undef if $theta > $omega), $intens is the
ratio of the intensity at the given point to the central intensity (0
if $theta > $omega), and $central is the central magnitude.

If this method is called in scalar context, it returns $point, the point
magnitude.

If the $omega argument is omitted or undefined, it is calculated based
on the geocentric range to the Sun at the current time setting of the
object.

If the $theta argument is omitted or undefined, the method returns
the average magnitude of the Sun, which is taken to be -26.8.

The limb-darkening algorithm and the associated constants come from
L<http://en.wikipedia.org/wiki/Limb_darkening>.

=cut

{	# Begin local symbol block

    my $central_mag;
    my @limb_darkening = (.3, .93, -.23);
    my $mean_mag = -26.8;

    sub magnitude {
    my ($self, $theta, $omega) = @_;
    return $mean_mag unless defined $theta;
    unless (defined $omega) {
	my @eci = $self->eci ();
	$omega = $self->get ('diameter') / 2 /
	    sqrt (distsq (\@eci[0 .. 2], [0, 0, 0]));
	}
    unless (defined $central_mag) {
	my $sum = 0;
	my $quotient = 2;
	foreach my $a (@limb_darkening) {
	    $sum += $a / $quotient++;
	    }
	$central_mag = $mean_mag - intensity_to_magnitude (2 * $sum);
	}
    my $intens = 0;
    my $point;
    if ($theta < $omega) {
	my $costheta = cos ($theta);
	my $cosomega = cos ($omega);
	my $sinomega = sin ($omega);
	my $cospsi = sqrt ($costheta * $costheta -
		$cosomega * $cosomega) / $sinomega;
	my $psiterm = 1;
	foreach my $a (@limb_darkening) {
	    $intens += $a * $psiterm;
	    $psiterm *= $cospsi;
	    }
	$point = $central_mag + intensity_to_magnitude ($intens);
	}
    return wantarray ? ($point, $intens, $central_mag) : $point;
    }
}	# End local symbol block.

=item ($time, $quarter, $desc) = $sun->next_quarter($want);

This method calculates the time of the next equinox or solstice
after the current time setting of the $sun object. The return is the
time, which equinox or solstice it is as a number from 0 (vernal
equinox) to 3 (winter solstice), and a string describing the equinox
or solstice. If called in scalar context, you just get the time.

The optional $want argument says which equinox or solstice you want.

As a side effect, the time of the $sun object ends up set to the
returned time.

The method of calculation is successive approximation, and actually
returns the second B<after> the calculated equinox or solstice.

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
Sun, what it actually returns is the sidereal period of the Earth,
per Appendix I (pg 408) of Jean Meeus' "Astronomical Algorithms,"
2nd edition.

=cut

sub period {31558149.7632}	# 365.256363 * 86400


=item $sun->time_set ()

This method sets coordinates of the object to the coordinates of the
Sun at the object's currently-set universal time.  The velocity
components are arbitrarily set to 0.

Although there's no reason this method can't be called directly, it
exists to take advantage of the hook in the B<Astro::Coord::ECI>
object, to allow the position of the Sun to be computed when the
object's time is set.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 25, pages 163ff.

=cut

#	The following constants are used in the time_set() method,
#	because Meeus' equations are in degrees, I was too lazy
#	to hand-convert them to radians, but I didn't want to
#	penalize the user for the conversion every time.


use constant SUN_C1_0 => deg2rad (1.914602);
use constant SUN_C1_1 => deg2rad (-0.004817);
use constant SUN_C1_2 => deg2rad (-0.000014);
use constant SUN_C2_0 => deg2rad (0.019993);
use constant SUN_C2_1 => deg2rad (0.000101);
use constant SUN_C3_0 => deg2rad (0.000289);
use constant SUN_LON_2000 => deg2rad (- 0.01397);

sub time_set {
my $self = shift;

my $time = $self->dynamical;


#	The following algorithm is from Meeus, chapter 25, page, 163 ff.

my $T = jcent2000 ($time);				# Meeus (25.1)
my $L0 = mod2pi (deg2rad ((.0003032 * $T + 36000.76983) * $T	# Meeus (25.2)
	+ 280.46646));
my $M = mod2pi (deg2rad (((-.0001537) * $T + 35999.05029)	# Meeus (25.3)
	* $T + 357.52911));
my $e = (-0.0000001267 * $T - 0.000042037) * $T + 0.016708634;	# Meeus (25.4)
my $C  = ((SUN_C1_2 * $T + SUN_C1_1) * $T + SUN_C1_0) * sin ($M)
	+ (SUN_C2_1 * $T + SUN_C2_0) * sin (2 * $M)
	+ SUN_C3_0 * sin (3 * $M);
my $O = $self->{_sun_geometric_longitude} = $L0 + $C;
my $omega = mod2pi (deg2rad (125.04 - 1934.156 * $T));
my $lambda = mod2pi ($O - deg2rad (0.00569 + 0.00478 * sin ($omega)));
my $nu = $M + $C;
my $R = (1.000_001_018 * (1 - $e * $e)) / (1 + $e * cos ($nu))
	* AU;
$self->{debug} and print <<eod;
Debug sun - @{[strftime '%d-%b-%Y %H:%M:%S', gmtime $time]}
    T  = $T
    L0 = @{[_rad2deg ($L0)]} degrees
    M  = @{[_rad2deg ($M)]} degrees
    e  = $e
    C  = @{[_rad2deg ($C)]} degrees
    O  = @{[_rad2deg ($O)]} degrees
    R  = @{[$R / AU]} AU
    omega = @{[_rad2deg ($omega)]} degrees
    lambda = @{[_rad2deg ($lambda)]} degrees
eod

$self->ecliptic (0, $lambda, $R);
$self->set (equinox_dynamical => $time);
$self;
}

1;

=back

=head1 ACKNOWLEDGMENTS

The author wishes to acknowledge Jean Meeus, whose book "Astronomical
Algorithms" (second edition) formed the basis for this module.

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

Copyright 2005, 2006, 2007 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself. Please see
L<http://perldoc.perl.org/index-licence.html> for the current licenses.

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
