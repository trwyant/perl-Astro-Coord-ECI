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
	$self->{$pkg}{period} = $args{period};
	$self->set(eccentricity => $args{eccentricity});
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
	s/^\s+//;
	$_ or next;
	substr($_, 0, 1) eq '#' and next;
	$tests++;
    }
    plan (tests => $tests);
    seek (DATA, $loc, 0);
}

my $test = 0;

while (<DATA>) {
    chomp;
    s/^\s+//;
    $_ or next;
    substr($_, 0, 1) eq '#' and next;
    $test++;
    my ($period, $eccentricity, $method, $want, $tolerance, $comment) = split '\s+', $_, 6;
    defined $tolerance or $tolerance = 1;
    my $tle = Astro::Coord::ECI::TLE::Period->new(
	period => $period, eccentricity => $eccentricity);
    my $got = $tle->$method();
    print <<eod;
#
# Test $test - $comment $method()
#          Want: $want
#           Got: $got
#     Tolerance: $tolerance
eod
    ok(abs ($want - $got) <= $tolerance);
}

1;
__DATA__

# All data from Space Track http://www.space-track.org/
# Their perigee and apogee data converted by adding 6378.14 km (the
# equatorial radius of the Earth according to Jean Meeus' "Astronomical
# Algorithms"). Semimajor is the average of their perigee and apogee,
# plus Meeus' radius of the Earth.

# period eccentricity method expect tolerance comment

 7970.4 0.1849966 semimajor  8624.14 1 OID 00005 (Vanguard 1) Epoch 09198.49982685
 7970.4 0.1849966 periapsis  7029.14 1 OID 00005 (Vanguard 1) Epoch 09198.49982685
 7970.4 0.1849966 apoapsis  10219.14 1 OID 00005 (Vanguard 1) Epoch 09198.49982685
 7970.4 0.1849966 perigee    7029.14 1 OID 00005 (Vanguard 1) Epoch 09198.49982685
 7970.4 0.1849966 apogee    10219.14 1 OID 00005 (Vanguard 1) Epoch 09198.49982685

 5487.6 0.0007102 semimajor  6724.64 1 OID 25544 (ISS) Epoch 09197.89571571
 5487.6 0.0007102 periapsis  6720.14 1 OID 25544 (ISS) Epoch 09197.89571571
 5487.6 0.0007102 apoapsis   6729.14 1 OID 25544 (ISS) Epoch 09197.89571571
 5487.6 0.0007102 perigee    6720.14 1 OID 25544 (ISS) Epoch 09197.89571571
 5487.6 0.0007102 apogee     6729.14 1 OID 25544 (ISS) Epoch 09197.89571571

43081.2 0.0134177 semimajor 26561.14 1 OID 20959 (Navstar 22) Epoch 09197.50368658
43081.2 0.0134177 periapsis 26203.14 2 OID 20959 (Navstar 22) Epoch 09197.50368658
43081.2 0.0134177 apoapsis  26919.14 2 OID 20959 (Navstar 22) Epoch 09197.50368658
43081.2 0.0134177 perigee   26203.14 2 OID 20959 (Navstar 22) Epoch 09197.50368658
43081.2 0.0134177 apogee    26919.14 2 OID 20959 (Navstar 22) Epoch 09197.50368658

43107.0 0.7271065 semimajor 26572.14 1 OID 21118 (Molniya 1-80) Epoch 09197.37303507
43107.0 0.7271065 periapsis  7251.14 1 OID 21118 (Molniya 1-80) Epoch 09197.37303507
43107.0 0.7271065 apoapsis  45893.14 1 OID 21118 (Molniya 1-80) Epoch 09197.37303507
43107.0 0.7271065 perigee    7251.14 1 OID 21118 (Molniya 1-80) Epoch 09197.37303507
43107.0 0.7271065 apogee    45893.14 1 OID 21118 (Molniya 1-80) Epoch 09197.37303507


