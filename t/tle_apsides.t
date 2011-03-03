package main;	# To make Perl::Critic happy.

use strict;
use warnings;

# The following is a quick ad-hoc way to get an object with a specified
# eccentricity and period.

package Astro::Coord::ECI::TLE::Period;	## no critic (ProhibitMultiplePackages)

use base qw{Astro::Coord::ECI::TLE};

{
    my $pkg = __PACKAGE__;

    sub new {
	my ($class, %args) = @_;
	my $self = $class->SUPER::new();
	$self->{$pkg}{period} = delete $args{period};
	$self->set(%args);
	return $self;
    }

    sub period {
	my ($self) = @_;
	return $self->{$pkg}{period};
    }
}

# And now, back to our regularly-scheduled test.

package main;	## no critic (ProhibitMultiplePackages)

use Astro::Coord::ECI::TLE;
use Test;

{
    my $tests = 0;
    my $loc = tell(DATA);
    while (<DATA>) {
	chomp;
	s{ \A \s+ }{}smx;
	$_ or next;
	substr($_, 0, 1) eq '#' and next;
	m{ \A new \b }smx or $tests++;
    }
    plan (tests => $tests);
    seek (DATA, $loc, 0);
}

my $test = 0;
my $tle;

while (<DATA>) {
    chomp;
    s{ \A \s+ }{}smx;
    $_ or next;
    substr($_, 0, 1) eq '#' and next;
    if (m{ \A new \b }smx) {
##	my ($method, $period, $eccentricity, $name) = split qr{\s+}, $_, 4;
	my (undef, $period, $eccentricity, $name) = split qr{\s+}, $_, 4;
	$tle = Astro::Coord::ECI::TLE::Period->new(
	    period => $period, eccentricity => $eccentricity, name => $name);
    } else {
	my ($method, $want, $tolerance) = split qr{\s+}, $_;
	defined $tolerance or $tolerance = 1;
	my $got = $tle->$method();
	print <<eod;
#
# Test $test - @{[$tle->get('name')]} $method()
#          Want: $want
#           Got: $got
#     Tolerance: $tolerance
eod
	ok(abs ($want - $got) <= $tolerance);
    }
}

1;
__DATA__

# All data from Space Track http://www.space-track.org/
# Their perigee and apogee data converted by adding 6378.14 km (the
# equatorial radius of the Earth according to Jean Meeus' "Astronomical
# Algorithms"). Semimajor is the average of their perigee and apogee,
# plus Meeus' radius of the Earth.

new 7970.4 0.1849966 OID 00005 (Vanguard 1) Epoch 09198.49982685
semimajor  8624.14 1
periapsis  7029.14 1
apoapsis  10219.14 1
perigee    7029.14 1
apogee    10219.14 1

new 5487.6 0.0007102 OID 25544 (ISS) Epoch 09197.89571571
semimajor  6724.64 1
periapsis  6720.14 1
apoapsis   6729.14 1
perigee    6720.14 1
apogee     6729.14 1

new 43081.2 0.0134177 OID 20959 (Navstar 22) Epoch 09197.50368658
semimajor 26561.14 1
periapsis 26203.14 2
apoapsis  26919.14 2
perigee   26203.14 2
apogee    26919.14 2

new 43107.0 0.7271065 OID 21118 (Molniya 1-80) Epoch 09197.37303507
semimajor 26572.14 1
periapsis  7251.14 1
apoapsis  45893.14 1
perigee    7251.14 1
apogee    45893.14 1
