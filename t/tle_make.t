package main;

use strict;
use warnings;

BEGIN {

    eval {
	require Test::More;
	Test::More->VERSION( 0.88 );	# Because of done_testing()
	Test::More->import();
	1;
    } or do {
	print "1..0 # Test::More 0.88 or higher required.\n";
	exit;
    };

}

# Note that this test is not distributed because I do not have the
# right to distribute the TLE data.

use Astro::Coord::ECI::TLE;

my @bodies;
{
    local $/ = undef;
    @bodies = Astro::Coord::ECI::TLE->parse( <DATA> );
}

plan( tests => scalar @bodies );

foreach my $tle ( @bodies ) {
    is( $tle->_make_tle(), $tle->get( 'tle' ), title( $tle ) );
}

sub title {
    my ( $tle ) = @_;
    my $data = $tle->get( 'tle' );
    my $name = join ' ', 'OID', $tle->get( 'id' );
    $data =~ tr/\n/\n/ > 2 or return $name;
    $data =~ m/ \n /smx;
    return $name . ' ' . substr $data, 0, $-[0];
}

1;
__DATA__
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
1 11801U          80230.29629788  .01431103  00000-0  14311-1       2
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848     2
Satellite X
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
Satellite X --effective 1980/275/12:00:00
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
--effective 1980/275/12:00:00
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
Satellite X --rcs 5.021
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
--rcs 5.021
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
Satellite X --effective 1980/275/12:00:00 --rcs 5.021
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
--effective 1980/275/12:00:00 --rcs 5.021
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    87
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  1058
