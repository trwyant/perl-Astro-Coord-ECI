package main;

use strict;
use warnings;

use lib qw{ inc };

use Astro::Coord::ECI::Satpass;
use Test::More 0.88;

eval {
    require Geo::Coder::Geocoder::US;
    1;
} or do {
    plan skip_all => 'Geo::Coder::Geocoder::US not available';
    exit;
};

eval {
    require LWP::UserAgent;
    1;
} or do {	# Shouldn't happen since Geo::Coder::Geocoder::US loaded.
    plan skip_all => 'LWP::UserAgent not available';
    exit;
};

{
    my $ua = LWP::UserAgent->new ();
    my $rslt = $ua->get ('http://rpc.geocoder.us/');
    unless ($rslt->is_success) {
	plan skip_all => 'http://rpc.geocoder.us/ not reachable';
	exit;
    }
}

Astro::Coord::ECI::Satpass::satpass (*DATA);

1;
__END__

## -skip not_available ('Geo::Coder::Geocoder::US') || not_reachable ('http://rpc.geocoder.us/')

set country us
set autoheight 0
geocode '1600 pennsylvania ave washington dc'
-data <<eod
set location '1600 Pennsylvania Ave NW, Washington DC 20502'
set latitude 38.898748
set longitude -77.037684
eod
-test geocode U.S. location via http://rpc.geocoder.us/

# BELOW HERE NOT TESTED BECAUSE GEOCODER.CA REQUIRES REGISTRATION FOR
# THEIR FREE PORT.

-end

-skip not_available ('XML::Parser') || not_reachable ('http://rpc.geocoder.ca/')

set country ca
set autoheight 0
geocode '80 Wellington Street, Ottawa ON'
-data <<eod
set location '80 Wellington Street, Ottawa ON'
set latitude 45.423388
set longitude -75.697786
eod
-test geocode Canadian location via http://rpc.geocoder.ca/
