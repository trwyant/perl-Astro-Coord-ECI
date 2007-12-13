use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use Test;

my $tle_file = 't/sgp4-ver.tle';
unless (-e $tle_file) {
    print "1..0 # skip $tle_file not available\n";
    warn <<eod;

Because I do not have authority to distribute TLE data, I have not
included sgp4-ver.tle in this kit. A copy is contained in
http://celestrak.com/publications/AIAA/2006-6753/AIAA-2006-6753.zip

If you wish to run this test, obtain and unzip the file, and place
sgp4-ver.tle in the t directory.

eod
    exit;
}

my @satrecs;
{
    local $/ = undef;	# Slurp mode.
    open (my $fh, '<', $tle_file) or die "Failed to open $tle_file: $!";
    my $data = <$fh>;
    @satrecs = Astro::Coord::ECI::TLE->parse ($data);
}

plan (tests => 2 * scalar @satrecs);
my $tolerance = 1;

print <<eod;
#
# This file does not really test anything, as I have no comparison data.
# What it does is to demonstrate the effect of the model used on the
# period calculated for a given satellite.
#
eod

my $test = 0;
my $tle;
my $oid;
my @gravconst = (72, 84);
my @max_delta = (0) x 2;
foreach my $tle (@satrecs) {
    my $oid = $tle->get ('id');
    $tle->set (model => 'model4');
    my $want = $tle->period ();
    $tle->set (model => 'model');
    foreach my $inx (0 .. 1) {
	my $const = $gravconst[$inx];
	$tle->set (gravconst_r => $const);
	my $got = $tle->period ();
	my $delta = $want - $got;
	$test++;
	print <<eod;
#
# Test $test - OID $oid period, gravconst_r = $const
#    Want: $want (old calculation)
#     Got: $got (new calculation)
#        Delta: $delta
#    Tolerance: $tolerance
eod
	ok (abs ($delta) <= $tolerance);
	abs $delta > abs ($max_delta[$inx]) and $max_delta[$inx] = $delta;
    }
}
print <<eod;
#
# Maximum delta by gravconst_r:
eod
foreach my $inx (0 .. 1) {
    print <<eod;
#    $gravconst[$inx] => $max_delta[$inx]
eod
}
