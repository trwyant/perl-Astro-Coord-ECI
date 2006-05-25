=head1 NAME

Astro::Coord::ECI::Utils - Utility routines for astronomical calculations

=head1 SYNOPSIS

 use Astro::Coord::ECI::Utils qw{:all};
 my $now = time ();
 print "The current Julian day is ", julianday ($now);

=head1 DESCRIPTION

This module was written to provide a home for all the constants and
utility subroutines used by B<Astro::Coord::ECI> and its descendents.
What ended up here was anything that was essentially a subroutine, not
a method.

This package exports nothing by default. But all the constants and
subroutines documented below are exportable, and the :all tag gets you
all of them.

The following constants are exportable:

 AU = number of kilometers in an astronomical unit
 LIGHTYEAR = number of kilometers in a light year
 PARSEC = number of kilometers in a parsec
 PERL2000 = January 1 2000, 12 noon universal, in Perl time
 PI = the circle ratio, computed as atan2 (0, -1)
 PIOVER2 = half the circle ratio
 SECSPERDAY = the number of seconds in a day
 TWOPI = twice the circle ratio

In addition, the following subroutines are exportable:

=over 4

=cut

use strict;
use warnings;

package Astro::Coord::ECI::Utils;

our $VERSION = "0.003_02";
our @ISA = qw{Exporter};

use Carp;
use Data::Dumper;
use POSIX qw{floor};
use Time::Local;
use UNIVERSAL qw{can isa};

our @EXPORT;
our @EXPORT_OK = qw{
	AU LIGHTYEAR PARSEC PERL2000 PI PIOVER2 SECSPERDAY TWOPI
	acos asin atmospheric_extinction deg2rad distsq equation_of_time
	intensity_to_magnitude jcent2000 jday2000
	julianday mod2pi nutation_in_longitude nutation_in_obliquity
	obliquity omega rad2deg tan theta0 thetag};

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
    );

use constant AU => 149597870;		# 1 astronomical unit, per Meeus, Appendix I pg 407.
use constant LIGHTYEAR => 9.4607e12;	# 1 light-year, per Meeus, Appendix I pg 407.
use constant PARSEC => 30.8568e12;	# 1 parsec, per Meeus, Appendix I pg 407.
use constant PERL2000 => timegm (0, 0, 12, 1, 0, 100);
use constant PI => atan2 (0, -1);
use constant PIOVER2 => PI / 2;
use constant SECSPERDAY => 86400;
### use constant SOLAR_RADIUS => 1392000 / 2;	# Meeus, Appendix I, page 407.
use constant TWOPI => PI * 2;


=item $angle = acos ($value)

This subroutine calculates the arc in radians whose cosine is the given
value.

=cut

sub acos {atan2 (sqrt (1 - $_[0] * $_[0]), $_[0])}


=item $angle = asin ($value)

This subroutine calculates the arc in radians whose sine is the given
value.

=cut

sub asin {atan2 ($_[0], sqrt (1 - $_[0] * $_[0]))}


=for comment help syntax-highlighting editor "

=item $magnitude = atmospheric_extinction ($elevation, $height);

This subroutine calculates the typical atmospheric extinction in
magnitudes at the given elevation above the horizon in radians and the
given height above sea level in kilometers.

The algorithm comes from Daniel W. E. Green's article "Magnitude
Corrections for Atmospheric Extinction", which was published in
the July 1992 issue of "International Comet Quarterly", and is
available online at
L<http://www.cfa.harvard.edu/icq/ICQExtinct.html>. The text of
this article makes it clear that the actual value of the
atmospheric extinction can vary greatly from the typical
values given even in the absence of cloud cover.

=for comment help syntax-highlighting editor "

=cut

#	Note that the "constant" 0.120 in Aaer (aerosol scattering) is
#	based on a compromise value A0 = 0.050 in Green's equation 3
#	(not exhibited here), which can vary from 0.035 in the winter to
#	0.065 in the summer. This makes a difference of a couple tenths
#	at 20 degrees elevation, but a couple magnitudes at the
#	horizon. Green also remarks that the 1.5 denominator in the
#	same equation (a.k.a. the scale height) can be up to twice
#	that.


sub atmospheric_extinction {
my ($elevation, $height) = @_;
my $cosZ = cos (PIOVER2 - $elevation);
my $X = 1/($cosZ + 0.025 * exp (-11 * $cosZ));	# Green 1
my $Aray = 0.1451 * exp (-$height / 7.996);	# Green 2
my $Aaer = 0.120 * exp (-$height / 1.5);	# Green 4
($Aray + $Aaer + 0.016) * $X;	# Green 5, 6
}


=item $rad = deg2rad ($degr)

This subroutine converts degrees to radians.

=cut

sub deg2rad {$_[0] * PI / 180}


=item $value = distsq (\@coord1, \@coord2)

This subroutine calculates the square of the distance between the two
sets of Cartesian coordinates. We do not take the square root here
because of cases (e.g. the law of cosines) where we would just have
to square the result again.

=cut

sub distsq {
ref $_[0] eq 'ARRAY' && ref $_[1] eq 'ARRAY' && @{$_[0]} == @{$_[1]} or
    die "Programming error - Both arguments to distsq must be ",
    "references to lists of the same length.";

my $sum = 0;
my $size = @{$_[0]};
for (my $inx = 0; $inx < $size; $inx++) {
    my $delta = $_[0][$inx] - $_[1][$inx];
    $sum += $delta * $delta;
    }
$sum
}


=item $seconds = equation_of_time ($time);

This method returns the equation of time at the given B<dynamical>
time.

The algorithm is from W. S. Smart's "Text-Book on Spherical Astronomy",
as reported in Jean Meeus' "Astronomical Algorithms", 2nd Edition,
Chapter 28, page 185.

=cut

sub equation_of_time {

my $time = shift;

my $epsilon = obliquity ($time);
my $y = tan ($epsilon / 2);
$y *= $y;


#	The following algorithm is from Meeus, chapter 25, page, 163 ff.

my $T = jcent2000 ($time);				# Meeus (25.1)
my $L0 = mod2pi (deg2rad ((.0003032 * $T + 36000.76983) * $T	# Meeus (25.2)
	+ 280.46646));
my $M = mod2pi (deg2rad (((-.0001537) * $T + 35999.05029)	# Meeus (25.3)
	* $T + 357.52911));
my $e = (-0.0000001267 * $T - 0.000042037) * $T + 0.016708634;	# Meeus (25.4)

my $E = $y * sin (2 * $L0) - 2 * $e * sin ($M) +
    4 * $e * $y * sin ($M) * cos (2 * $L0) -
    $y * $y * .5 * sin (4 * $L0) -
    1.25 * $e * $e * sin (2 * $M);				# Meeus (28.3)

$E * SECSPERDAY / TWOPI;	# The formula gives radians.
}


=for comment help syntax-highlighting editor "

=item $difference = intensity_to_magnitude ($ratio)

This method converts a ratio of light intensities to a difference in
stellar magnitudes. The algorithm comes from Jean Meeus' "Astronomical
Algorithms", Second Edition, Chapter 56, Page 395.

Note that, because of the way magnitudes work (a more negative number
represents a brighter star) you get back a positive result for an
intensity ratio less than 1, and a negative result for an intensity
ratio greater than 1.

=for comment help syntax-highlighting editor "

=cut

{	# Begin local symbol block
    my $intensity_to_mag_factor;	# Calculate only if needed.
    sub intensity_to_magnitude {
    - ($intensity_to_mag_factor ||= 2.5 / log (10)) * log ($_[0]);
    }
}


=for comment help syntax-highlighting editor "

=item $century = jcent2000 ($time);

Several of the algorithms in Jean Meeus' "Astronomical Algorithms"
are expressed in terms of the number of Julian centuries from epoch
J2000.0 (e.g equations 12.1, 22.1). This subroutine encapsulates
that calculation.


=for comment help syntax-highlighting editor "

=cut

sub jcent2000 {
jday2000 ($_[0]) / 36525;
}


=item $jd = jday2000 ($time);

This subroutine converts a Perl date to the number of Julian days
(and fractions thereof) since Julian 2000.0. This quantity is used
in a number of the algorithms in Jean Meeus' "Astronomical
Algorithms".

The computation makes use of information from Jean Meeus' "Astronomical
Algorithms", 2nd Edition, Chapter 7, page 62.

=cut

sub jday2000 {
($_[0] - PERL2000) / SECSPERDAY			#   Meeus p. 62
}


=for comment help syntax-highlighting editor "

=item $jd = julianday ($time);

This subroutine converts a Perl date to a Julian day number.

The computation makes use of information from Jean Meeus' "Astronomical
Algorithms", 2nd Edition, Chapter 7, page 62.

=for comment help syntax-highlighting editor "

=cut

sub julianday {
jday2000($_[0]) + 2_451_545.0	#   Meeus p. 62
}


=item $theta = mod2pi ($theta)

This subrouting reduces the given angle in radians to the range 0 <=
$theta < TWOPI.

=cut

sub mod2pi {
$_[0] - floor ($_[0] / TWOPI) * TWOPI;
}


=for comment help syntax-highlighting editor "

=item $delta_psi = nutation_in_longitude ($time)

This subroutine calculates the nutation in longitude (delta psi) for
the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff. Meeus states that it is good to
0.5 seconds of arc.

=for comment help syntax-highlighting editor "

=cut

sub nutation_in_longitude {

my $time = shift;
my $T = jcent2000 ($time);	# Meeus (22.1)

my $omega = mod2pi (deg2rad ((($T / 450000 + .0020708) * $T -
	1934.136261) * $T + 125.04452));

my $L = mod2pi (deg2rad (36000.7698 * $T + 280.4665));
my $Lprime = mod2pi (deg2rad (481267.8813 * $T + 218.3165));
my $delta_psi = deg2rad ((-17.20 * sin ($omega) - 1.32 * sin (2 * $L)
	- 0.23 * sin (2 * $Lprime) + 0.21 * sin (2 * $omega))/3600);

$delta_psi;
}


=for comment help syntax-highlighting editor "

=item $delta_epsilon = nutation_in_obliquity ($time)

This subroutine calculates the nutation in obliquity (delta epsilon)
for the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff. Meeus states that it is good to
0.1 seconds of arc.

=for comment help syntax-highlighting editor "

=cut

sub nutation_in_obliquity {

my $time = shift;
my $T = jcent2000 ($time);	# Meeus (22.1)

my $omega = mod2pi (deg2rad ((($T / 450000 + .0020708) * $T -
	1934.136261) * $T + 125.04452));

my $L = mod2pi (deg2rad (36000.7698 * $T + 280.4665));
my $Lprime = mod2pi (deg2rad (481267.8813 * $T + 218.3165));
my $delta_epsilon = deg2rad ((9.20 * cos ($omega) + 0.57 * cos (2 * $L) +
	0.10 * cos (2 * $Lprime) - 0.09 * cos (2 * $omega))/3600);

$delta_epsilon;
}


=for comment help syntax-highlighting editor "

=item $epsilon = obliquity ($time)

This subroutine calculates the obliquity of the ecliptic in radians at
the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff. The conversion from universal to
dynamical time comes from chapter 10, equation 10.2  on page 78.

=for comment help syntax-highlighting editor "

=cut

use constant E0BASE => (21.446 / 60 + 26) / 60 + 23;

sub obliquity {

my $time = shift;

my $T = jcent2000 ($time);	# Meeus (22.1)

my $delta_epsilon = nutation_in_obliquity ($time);

my $epsilon0 = deg2rad (((0.001813 * $T - 0.00059) * $T - 46.8150)
	* $T / 3600 + E0BASE);
$epsilon0 + $delta_epsilon;
}

=for comment help syntax-highlighting editor "

=item $radians = omega ($time);

This subroutine calculates the ecliptic longitude of the ascending node
of the Moon's mean orbit at the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff.

=for comment help syntax-highlighting editor "

=cut

sub omega {
my $T = jcent2000 (shift);	# Meeus (22.1)

my $omega = mod2pi (deg2rad ((($T / 450000 + .0020708) * $T -
	1934.136261) * $T + 125.04452));
}


=item $degrees = rad2deg ($radians)

This subroutine converts the given angle in radians to its equivalent
in degrees.

=cut

sub rad2deg {$_[0] / PI * 180}


=begin comment

#	($xprime, $yprime) = _rotate ($theta, $x, $y)

#	Rotate coordinates in the Cartesian plane.
#	The arguments are the angle and the coordinates, and
#	the rotated coordinates 

sub _rotate {
my ($theta, $x, $y) = @_;
my $costh = cos ($theta);
my $sinth = sin ($theta);
($x * $costh - $y * $sinth, $x * $sinth + $y * $costh);
}

=end comment

=item $value = tan ($angle)

This subroutine computes the tangent of the given angle in radians.

=cut

sub tan {sin ($_[0]) / cos ($_[0])}


=item $value = theta0 ($time);

This subroutine returns the Greenwich hour angle of the mean equinox at
0 hours universal on the day whose time is given (i.e. the argument is
a standard Perl time).

=cut

sub theta0 {
thetag (timegm (0, 0, 0, (gmtime $_[0])[3 .. 5]));
}


=for comment help syntax-highlighting editor "

=item $value = thetag ($time);

This subroutine returns the Greenwich hour angle of the mean equinox at
the given time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, equation 12.4, page 88.

=for comment help syntax-highlighting editor "

=cut


#	Meeus, pg 88, equation 12.4, converted to radians and Perl dates.

sub thetag {
my $T = jcent2000 ($_[0]);
mod2pi (4.89496121273579 + 6.30038809898496 *
	jday2000 ($_[0]))
	+ (6.77070812713916e-06 - 4.5087296615715e-10 * $T) * $T * $T;
}

1;

__END__

=back

=head1 ACKNOWLEDGEMENTS

The author wishes to acknowledge Jean Meeus, whose book "Astronomical
Algorithms" (second edition) published by Willmann-Bell Inc
(L<http://www.willbell.com/>) provided several of the algorithms
implemented herein.

=head1 BUGS

Bugs can be reported to the author by mail, or through
L<http://rt.cpan.org/>.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2005, 2006 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

This module is free software; you can use it, redistribute it and/or
modify it under the same terms as Perl itself. Please see
L<http://perldoc.perl.org/index-licence.html> for the current licenses.

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
