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

This package exports nothing by default. But all the constants,
variables, and subroutines documented below are exportable, and the :all
tag gets you all of them.

=head2 The following constants are exportable:

 AU = number of kilometers in an astronomical unit
 JD_OF_EPOCH = the Julian Day of Perl epoch 0
 LIGHTYEAR = number of kilometers in a light year
 PARSEC = number of kilometers in a parsec
 PERL2000 = January 1 2000, 12 noon universal, in Perl time
 PI = the circle ratio, computed as atan2 (0, -1)
 PIOVER2 = half the circle ratio
 SECSPERDAY = the number of seconds in a day
 TWOPI = twice the circle ratio

=head2 The following global variable is exportable:

=head3 $DATETIMEFORMAT

This variable represents the POSIX::strftime format used to convert
times to strings. The default value is '%a %b %d %Y %H:%M:%S' to be
consistent with the behavior of gmtime (or, to be precise, the
behavior of ctime as documented on my system).

=head3 $JD_GREGORIAN

This variable represents the Julian Day of the switch from Julian to
Gregorian calendars. This is used by date2jd(), jd2date(), and the
routines which depend on them, for deciding whether the date is to be
interpreted as in the Julian or Gregorian calendar. Its initial setting
is 2299160.5, which represents midnight October 15 1582 in the Gregorian
calendar, which is the date that calendar was first adopted. This is
slightly different than the value of 2299161 (noon of the same day) used
by Jean Meeus.

If you are interested in historical calculations, you may wish to reset
this appropriately. If you use date2jd to calculate the new value, be
aware of the effect the current setting of $JD_GREGORIAN has on the
interpretation of the date you give.

=head2 In addition, the following subroutines are exportable:

=over 4

=cut

use strict;
use warnings;

package Astro::Coord::ECI::Utils;

our $VERSION = '0.008_01';
our @ISA = qw{Exporter};

use Carp;
use Data::Dumper;
use POSIX qw{floor strftime};
use Time::Local;
use UNIVERSAL qw{can isa};

our @EXPORT;
our @EXPORT_OK = qw{
	AU $DATETIMEFORMAT $JD_GREGORIAN JD_OF_EPOCH LIGHTYEAR PARSEC
	PERL2000 PI PIOVER2 SECSPERDAY TWOPI acos asin
	atmospheric_extinction date2epoch date2jd deg2rad distsq
	dynamical_delta epoch2datetime equation_of_time find_first_true
	intensity_to_magnitude jcent2000 jd2date jd2datetime jday2000
	julianday load_module looks_like_number max min mod2pi
	nutation_in_longitude nutation_in_obliquity obliquity omega
	rad2deg tan theta0 thetag};

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
    );

use constant AU => 149597870;		# 1 astronomical unit, per
					# Meeus, Appendix I pg 407.
use constant LIGHTYEAR => 9.4607e12;	# 1 light-year, per Meeus,
					# Appendix I pg 407.
use constant PARSEC => 30.8568e12;	# 1 parsec, per Meeus,
					# Appendix I pg 407.
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

sub acos {

    abs ($_[0]) > 1 and confess <<eod;
Programming error - Trying to take the arc cosine of a number greater
        than 1.
eod

    atan2 (sqrt (1 - $_[0] * $_[0]), $_[0])
}


=item $angle = asin ($value)

This subroutine calculates the arc in radians whose sine is the given
value.

=cut

sub asin {atan2 ($_[0], sqrt (1 - $_[0] * $_[0]))}


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


=item $jd = date2jd ($sec, $min, $hr, $day, $mon, $yr)

This subroutine converts the given date to the corresponding Julian day.
The inputs are as for B<Time::Local::timegm>; $mon is in the range 0 -
11, and $yr is from 1900, with earlier years being negative. The year 1
BC is represented as -1900.

If less than 6 arguments are provided, zeroes will be prepended to the
argument list as needed.

The date is presumed to be in the Gregorian calendar. If the resultant
Julian Day is before $JD_GREGORIAN, the date is reinterpreted as being
from the Julian calendar.

The only validation is that the month be between 0 and 11 inclusive, and
that the year be not less than -6612 (4713 BC). Fractional days are
accepted.

The algorithm is from Jean Meeus' "Astronomical Algorithms", second
edition, chapter 7 ("Julian Day"), pages 60ff, but the month is
zero-based, not 1-based, and years are 1900-based.

=cut

our $DATETIMEFORMAT;
our $JD_GREGORIAN;
BEGIN {
    $DATETIMEFORMAT = '%a %b %d %Y %H:%M:%S';
    $JD_GREGORIAN = 2299160.5;
}

sub date2jd {
    unshift @_, 0 while @_ < 6;
    my ($sec, $min, $hr, $day, $mon, $yr) = @_;
    $mon++;		# Algorithm expects month 1-12.
    $yr += 1900;	# Algorithm expects zero-based year.
    $yr < -4712 and croak "Error - Invalid year $yr";
    $mon < 1 || $mon > 12 and croak "Error - Invalid month $mon";
    if ($mon < 3) {
	--$yr;
	$mon += 12;
    }
    my $A = floor ($yr / 100);
    my $B = 2 - $A + floor ($A / 4);
    my $jd = floor (365.25 * ($yr + 4716)) +
	floor (30.6001 * ($mon + 1)) + $day + $B - 1524.5 +
	((($sec || 0) / 60 + ($min || 0)) / 60 + ($hr || 0)) / 24;
    $jd < $JD_GREGORIAN and
	$jd = floor (365.25 * ($yr + 4716)) +
	floor (30.6001 * ($mon + 1)) + $day - 1524.5 +
	((($sec || 0) / 60 + ($min || 0)) / 60 + ($hr || 0)) / 24;
    $jd;
}

use constant JD_OF_EPOCH => date2jd (gmtime (0));


=item $epoch = date2epoch ($sec, $min, $hr, $day, $mon, $yr)

This is a convenience routine that converts the given date to seconds
since the epoch, going through date2jd() to do so. The arguments are the
same as those of date2jd().

If less than 6 arguments are provided, zeroes will be prepended to the
argument list as needed.

The functionality is the same as B<Time::Local::timegm>, but this
function lacks timegm's limited date range.

=cut

sub date2epoch {
    unshift @_, 0 while @_ < 6;
    my ($sec, $min, $hr, $day, $mon, $yr) = @_;
    (date2jd ($day, $mon, $yr) - JD_OF_EPOCH) * SECSPERDAY +
    (($hr || 0) * 60 + ($min || 0)) * 60 + ($sec || 0);
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
    confess <<eod;
Programming error - Both arguments to distsq must be  references to
        lists of the same length.
eod

my $sum = 0;
my $size = @{$_[0]};
for (my $inx = 0; $inx < $size; $inx++) {
    my $delta = $_[0][$inx] - $_[1][$inx];
    $sum += $delta * $delta;
    }
$sum
}


=item $seconds = dynamical_delta ($time);

This method returns the difference between dynamical and universal time
at the given universal time. That is,

 $dynamical = $time + dynamical_delta ($time)

if $time is universal time.

The algorithm is from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 10, page 78.

=cut

sub dynamical_delta {
my $year = (gmtime $_[0])[5] + 1900;
my $t = ($year - 2000) / 100;
my $correction = .37 * ($year - 2100);	# Meeus' correction to (10.2)
(25.3 * $t + 102) * $t + 102		# Meeus (10.2)
	+ $correction;			# Meeus' correction.
}


=item ($sec, $min, $hr, $day, $mon, $yr, $wday, $yday, 0) = epoch2datetime ($epoch)

This convenience subroutine converts the given time in seconds from the
system epoch to the corresponding date and time. It is implemented in
terms of jd2date (), with the year and month returned from that
subroutine. The day is a whole number, with the fractional part
converted to hours, minutes, and seconds. The $wday is the day of the
week, with Sunday being 0. The $yday is the day of the year, with
January 1 being 0. The trailing 0 is the summer time (or daylight saving
time) indicator which is always 0 to be consistent with gmtime.

If called in scalar context, it returns the date formatted by
POSIX::strftime, using the format string in $DATETIMEFORMAT.

The functionality is similar to gmtime, but lacks gmtime's limited date
range.

The input must convert to a non-negative Julian date. The exact lower
limit depends on the system, but is computed by -(JD_OF_EPOCH * 86400).
For Unix systems with an epoch of January 1 1970, this is -210866760000.

Additional algorithms for day of week and day of year come from Jean
Meeus' "Astronomical Algorithms", 2nd Edition, Chapter 7 (Julian Day),
page 65.

=cut

sub epoch2datetime {
    my $day = floor ($_[0] / SECSPERDAY);
    my $sec = $_[0] - $day * SECSPERDAY;
    ($day, my $mon, my $yr, my $greg, my $leap) = jd2date (
	my $jd = $day + JD_OF_EPOCH);
    $day = floor ($day + .5);
    my $min = floor ($sec / 60);
    $sec = $sec - $min * 60;
    my $hr = floor ($min / 60);
    $min = $min - $hr * 60;
    my $wday = ($jd + 1.5) % 7;
    my $yd = floor (275 * ($mon + 1) / 9) - (2 - $leap) * floor (($mon +
	10) / 12) + $day - 31;
    wantarray and return ($sec, $min, $hr, $day, $mon, $yr, $wday, $yd,
	0);
    return strftime ($DATETIMEFORMAT, $sec, $min, $hr, $day, $mon, $yr,
	$wday, $yd, 0);
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


=item $time = find_first_true ($start, $end, \&test, $limit);

This function finds the first time between $start and $end for which
test ($time) is true. The resolution is $limit, which defaults to 1 if
not specified. If the times are reversed (i.e. the start time is after
the end time) the time returned is the last time test ($time) is true.

The test () function is assumed to be false for the first part of the
interval, and true for the rest. If this assumption is violated, the
result of this subroutine should be considered meaningless.

The calculation is done by, essentially, a binary search; the interval
is repeatedly split, the function is evaluated at the midpoint, and a
new interval selected based on whether the result is true or false.

Actually, nothing in this function says the independent variable has to
be time.

=cut

sub find_first_true {
    my ($begin, $end, $test, $limit) = @_;
    $limit ||= 1;
    if ($limit >= 1) {
	if ($begin <= $end) {
	    $begin = floor ($begin);
	    $end = floor ($end) == $end ? $end : floor ($end) + 1;
	} else {
	    $end = floor ($end);
	    $begin = floor ($begin) == $begin ? $begin : floor ($begin) + 1;
	}
    }
    my $iterator = (
	$end > $begin ?
	sub {$end - $begin > $limit} :
	sub {$begin - $end > $limit});
##    while ($end - $begin > $limit) {
    while ($iterator->()) {
	my $mid = $limit >= 1 ?
	    floor (($begin + $end) / 2) : ($begin + $end) / 2;
	($begin, $end) = ($test->($mid)) ?
	    ($begin, $mid) : ($mid, $end);
    }
    $end;
}


=item $difference = intensity_to_magnitude ($ratio)

This method converts a ratio of light intensities to a difference in
stellar magnitudes. The algorithm comes from Jean Meeus' "Astronomical
Algorithms", Second Edition, Chapter 56, Page 395.

Note that, because of the way magnitudes work (a more negative number
represents a brighter star) you get back a positive result for an
intensity ratio less than 1, and a negative result for an intensity
ratio greater than 1.

=cut

{	# Begin local symbol block
    my $intensity_to_mag_factor;	# Calculate only if needed.
    sub intensity_to_magnitude {
    - ($intensity_to_mag_factor ||= 2.5 / log (10)) * log ($_[0]);
    }
}


=item ($day, $mon, $yr, $greg, $leap) = jd2date ($jd)

This subroutine converts the given Julian day to the corresponding date.
The returns are year - 1900, month (0 to 11), day (which may have a
fractional part), a Gregorian calendar indicator which is true if the
date is in the Gregorian calendar and false if it is in the Julian
calendar, and a leap (or bissextile) year indicator which is true if the
year is a leap year and false otherwise. The year 1 BC is returned as
-1900 (i.e. as year 0), and so on. The date will probably have a
fractional part (e.g. 2006 1 1.5 for noon January first 2006).

If the $jd is before $JD_GREGORIAN, the date will be in the Julian
calendar; otherwise it will be in the Gregorian calendar.

The input may not be less than 0.

The algorithm is from Jean Meeus' "Astronomical Algorithms", second
edition, chapter 7 ("Julian Day"), pages 63ff, but the month is
zero-based, not 1-based, and the year is 1900-based.

=cut

sub jd2date {
    my $mod_jd = $_[0] + 0.5;
    my $Z = floor ($mod_jd);
    my $F = $mod_jd - $Z;
    my $A = (my $julian = $Z < $JD_GREGORIAN) ? $Z : do {
	my $alpha = floor (($Z - 1867216.25)/36524.25);
	$Z + 1 + $alpha - floor ($alpha / 4);
    };
    my $B = $A + 1524;
    my $C = floor (($B - 122.1) / 365.25);
    my $D = floor (365.25 * $C);
    my $E = floor (($B - $D) / 30.6001);
    my $day = $B - $D - floor (30.6001 * $E) + $F;
    my $mon = $E < 14 ? $E - 1 : $E - 13;
    my $yr = $mon > 2 ? $C - 4716 : $C - 4715;
    ($day, $mon - 1, $yr - 1900, !$julian, ($julian ? !($yr % 4) : (
		$yr % 400 ? $yr % 100 ? !($yr % 4) : 0 : 1)));
##	% 400 ? 1 : $yr % 100 ? 0 : !($yr % 4))));
}


=item ($sec, $min, $hr, $day, $mon, $yr, $wday, $yday, 0) = jd2datetime ($jd)

This convenience subroutine converts the given Julian day to the
corresponding date and time. All this really does is converts its
argument to seconds since the system epoch, and pass off to
epoch2datetime().

The input may not be less than 0.

=cut

sub jd2datetime {

=begin comment

    my ($day, $mon, $yr) = jd2date (@_);
    my $hr = $day;
    $day = floor ($day);
    my $min = $hr = ($hr - $day) * 24;
    $hr = floor ($hr);
    my $sec = $min = ($min - $hr) * 60;
    $min = floor ($min);
    $sec = ($sec - $min) * 60;
    wantarray and return ($sec, $min, $hr, $day, $mon, $yr);
    return strftime ($DATETIMEFORMAT, $yr, $mon, $day, $hr, $min, $sec);

=end comment

=cut

    $_[0] = ($_[0] - JD_OF_EPOCH) * SECSPERDAY;
    goto &epoch2datetime;
}


=item $century = jcent2000 ($time);

Several of the algorithms in Jean Meeus' "Astronomical Algorithms"
are expressed in terms of the number of Julian centuries from epoch
J2000.0 (e.g equations 12.1, 22.1). This subroutine encapsulates
that calculation.

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


=item $jd = julianday ($time);

This subroutine converts a Perl date to a Julian day number.

The computation makes use of information from Jean Meeus' "Astronomical
Algorithms", 2nd Edition, Chapter 7, page 62.

=cut

sub julianday {
jday2000($_[0]) + 2_451_545.0	#   Meeus p. 62
}

=item $rslt = load_module ($module_name)

This convenience method loads the named module (using 'require'),
throwing an exception if the load fails. Results are cached, and
subsequent attempts to load the same module simply give the cached
results.

=cut

{	# Local symbol block. Oh, for 5.10 and state variables.
    my %error;
    my %rslt;
    sub load_module {
	my  ($module) = @_;
	exists $error{$module} and croak $error{$module};
	exists $rslt{$module} and return $rslt{$module};
	$rslt{$module} = eval "require $module";
	$@ and croak ($error{$module} = $@);
	return $rslt{$module};
    }
}	# End local symbol block.


=item $boolean = looks_like_number ($string);

This subroutine returns true if the input looks like a number. It uses
Scalar::Util::looks_like_number if that is available, otherwise it uses
its own code, which is lifted verbatim from Scalar::Util 1.19, which in
turn leans heavily on perlfaq4.

=cut

unless (eval {require Scalar::Util; Scalar::Util->import
	('looks_like_number'); 1}) {
    *looks_like_number = sub {
	local $_ = shift;

	# checks from perlfaq4
	return 0 if !defined($_) or ref($_);
	return 1 if (/^[+-]?\d+$/); # is a +/- integer
	return 1 if (/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/); # a C float
	return 1 if ($] >= 5.008 and /^(Inf(inity)?|NaN)$/i)
	    or ($] >= 5.006001 and /^Inf$/i);

	0;
    };
}


=item $maximum = max (...);

This subroutine returns the maximum of its arguments.  If List::Util can
be loaded and 'max' imported, that's what you get. Otherwise you get a
pure Perl implementation.

=cut

unless (eval {require List::Util; List::Util->import ('max'); 1}) {
    *max = sub {
	my $rslt;
	foreach (@_) {
	    defined $_ or next;
	    if (!defined $rslt || $_ > $rslt) {
		$rslt = $_;
	    }
	}
	$rslt;
    };
}


=item $minimum = min (...);

This subroutine returns the minimum of its arguments.  If List::Util can
be loaded and 'min' imported, that's what you get. Otherwise you get a
pure Perl implementation.

=cut

unless (eval {require List::Util; List::Util->import ('min'); 1}) {
    *min = sub {
	my $rslt;
	foreach (@_) {
	    defined $_ or next;
	    if (!defined $rslt || $_ < $rslt) {
		$rslt = $_;
	    }
	}
	$rslt;
    };
}


=item $theta = mod2pi ($theta)

This subroutine reduces the given angle in radians to the range 0 <=
$theta < TWOPI.

=cut

sub mod2pi {
$_[0] - floor ($_[0] / TWOPI) * TWOPI;
}


=item $delta_psi = nutation_in_longitude ($time)

This subroutine calculates the nutation in longitude (delta psi) for
the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff. Meeus states that it is good to
0.5 seconds of arc.

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


=item $delta_epsilon = nutation_in_obliquity ($time)

This subroutine calculates the nutation in obliquity (delta epsilon)
for the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff. Meeus states that it is good to
0.1 seconds of arc.

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


=item $epsilon = obliquity ($time)

This subroutine calculates the obliquity of the ecliptic in radians at
the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff. The conversion from universal to
dynamical time comes from chapter 10, equation 10.2  on page 78.

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


=item $radians = omega ($time);

This subroutine calculates the ecliptic longitude of the ascending node
of the Moon's mean orbit at the given B<dynamical> time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, Chapter 22, pages 143ff.

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


=item $value = thetag ($time);

This subroutine returns the Greenwich hour angle of the mean equinox at
the given time.

The algorithm comes from Jean Meeus' "Astronomical Algorithms", 2nd
Edition, equation 12.4, page 88.

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

=head1 ACKNOWLEDGMENTS

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

Copyright 2005, 2006, 2007 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

=head1 LICENSE

This module is free software; you can use it, redistribute it and/or
modify it under the same terms as Perl itself. Please see
L<http://perldoc.perl.org/index-licence.html> for the current licenses.

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
