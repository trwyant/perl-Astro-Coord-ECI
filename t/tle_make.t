use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use Test;

BEGIN {plan tests => 3};

my $data;
my $test;
while (<DATA>) {
    $data .= $_;
    if (m/^2/) {
	my ($tle) = Astro::Coord::ECI::TLE->parse($data);
	my $got = $tle->_make_tle();
	$test++;
	my $oid = $tle->get('id');
	my ($gt, $et) = comment ($got, $data);
	print <<eod;
#
# Test $test: OID $oid
# Expected:
$et
#      Got:
$gt
eod
	ok ($got eq $data);
	$data = undef;
    }
}
sub comment {
    my @rslt;
    foreach (@_) {
	if (defined $_) {
	    push @rslt, join ('', map "# $_\n", grep $_, split "\n", $_);
	} else {
	    push @rslt, "undef\n";
	}
	chomp $rslt[-1];
    }
    return wantarray ? @rslt : $rslt[0];
}
__END__
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
1 11801U          80230.29629788  .01431103  00000-0  14311-1       2
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848     2
ISS (ZARYA)
1 25544U 98067A   08314.54872019  .00010072  00000-0  78333-4 0  6177
2 25544  51.6442 351.2199 0003657 328.8588 184.0286 15.72469917571404
