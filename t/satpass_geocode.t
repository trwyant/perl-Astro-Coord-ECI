package main;

use strict;
use warnings;

our $VERSION = '0.006';

use t::Satpass;

eval {require SOAP::Lite};
if ($@) {
    print "1..0 # skip Soap::Lite not available\n";
    exit;
}
eval {require LWP::UserAgent};
if ($@) {	# Shouldn't happen since SOAP::Lite loaded.
    print "1..0 # skip LWP::UserAgent not available\n";
    exit;
}
{
    my $ua = LWP::UserAgent->new ();
    my $rslt = $ua->get ('http://rpc.geocoder.us/');
    unless ($rslt->is_success) {
	print "1..0 # skip http://rpc.geocoder.us/ not reachable.\n";
	exit;
    }
}

t::Satpass::satpass (*DATA);

1;
__END__

## -skip not_available ('SOAP::Lite') || not_reachable ('http://rpc.geocoder.us/')

set country us
set autoheight 0
geocode '1600 pennsylvania ave washington dc'
-data <<eod

1600 Pennsylvania Ave NW
Washington DC 20502

set location '1600 Pennsylvania Ave NW Washington DC 20502'
set latitude 38.898748
set longitude -77.037684
eod
-test geocode U.S. location via http://rpc.geocoder.us/

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

# WE NO LONGER TEST BELOW HERE, BECAUSE ELEVATION FUNCTIONALITY HAS BEEN
# MOVED TO Geo::WebService::Elevation::USGS, WHICH HAS ITS OWN TESTING
# SUITE.

-end

# -skip not_available ('SOAP::Lite', 'XML::Parser') || not_reachable ('http://gisdata.usgs.gov/') || 'http://gisdata.usgs.gov/ seems to be returning 0 these days.'
-skip not_available ('SOAP::Lite', 'XML::Parser') || not_reachable ('http://gisdata.usgs.gov/')

set country us
set location '1600 Pennsylvania Ave NW Washington DC 20502'
set latitude 38.898748
set longitude -77.037684
set height 0
height
-fail <<eod
Test %d may fail due to a database problem on http://gisdata.usgs.gov/
or due to a change in the interface specification. If you want to
distinguish between the two, visit that site and look up the height
at latitude 38.898748 (Y_value) longitude -77.037684 (X_value) by hand.
eod
-data set height 16.67
# Above was 16.90; changed sometime before 12-Aug-2008. New value discovered
# after fixing my code for the fact that the USGS was finally putting out
# valid XML, which SOAP was parsing, so I got back a hash rather than a
# string.
# Above was 16.68; changed 17-Apr-2007 after it had been this way for a while
-test fetch height in continental U.S. from http://gisdata.usgs.gov/
# Make the above -todo since fails for server errors sometimes.
-todo

set country ca
set location '80 Wellington Street Ottawa ON'
set latitude 45.423388
set longitude -75.697786
set height 0
height
# As of 17-Apr-2007
# -data set height 82.00
# As of 19-Oct-2007
-data set height 89.00
-fail <<eod
Test %d may fail due to a database problem on http://gisdata.usgs.gov/
or due to a change in the interface specification. If you want to
distinguish between the two, visit that site and look up the height
at latitude 45.423388 (Y_value) longitude -75.697786 (X_value) by hand.

This test may also occasionally fail because http://gisdata.usgs.gov/
returned zero for the height. I consider this to be a server bug,
not a bug in satpass.
eod
-test fetch height in Canada from http://gisdata.usgs.gov/
# Make the above -todo since it seems to fail so often.
-todo

-skip ''
