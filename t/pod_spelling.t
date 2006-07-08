#!/usr/local/bin/perl

use strict;
use warnings;

my $skip;
BEGIN {
    eval "use Test::Spelling";
    $@ and do {
	eval "use Test";
	plan (tests => 1);
	$skip = 'Test::Spelling not available';;
    };
}

our $VERSION = '0.002';

if ($skip) {
    skip ($skip, 1);
} else {
    add_stopwords (<DATA>);

    all_pod_files_spelling_ok ();
}
__DATA__
Above's
accreted
Alasdair
altazimuth
angulardiameter
angularvelocity
appulse
argumentofperigee
Astro
au
autoheight
azel
barycentre
body's
boosters
Borkowski
Borkowski's
Brett
Brodowski
bstardrag
CA
ca
Celestrak
Chalpront
cmd
coodinate
Coords
dans
darwin
de
deg
degreesDminutesMsecondsS
des
distsq
Dominik
ds
du
ECEF
ECI
eci
EDT
edt
edu
elementnumber
ELP
ephemeristype
Escobal
EST
exportable
ff
firstderivative
fr
Francou
Fugina
geocode
Geocoder
geocoder
GMT
Green's
harvard
IDs
illum
illuminator
ini
internet
jan
jcent
jday
Jenness
jul
julianday
Kazimierz
Kelso
Kelso's
lib
ls
Lune
ly
magma
Mariana
McCants
meananomaly
meanmotion
Meeus
mma
mmas
Moon's
MoonPhase
MSWin
NORAD
NORAD's
nouvelles
Obliquity
obliquity
Observatoire
op
oped
orbitaux
Palau
parametres
pbcopy
pbpaste
pc
PE
perigee
perltime
Persei
pg
pm
pp
pre
psiprime
rad
Ramon
readonly
rebless
reblessed
reblesses
reblessing
reportable
revolutionsatepoch
Rico
rightascension
Roehric
Saemundsson's
SATCAT
satpass
SATPASSINI
SDP
sdp
secondderivative
semimajor
SGP
sgp
SIGINT
SIMBAD
simbad
SKYSAT
skysat
SLALIB
Smart's
solstices
SPACETRACK
Spacetrack
Storable
strasbg
SunTime
Survey's
Terre
thetag
Thorfinn
TIMEZONES
TLE
tle
Touze
Turbo
TWOPI
tz
uk
USGS
VA
valeurs
webcmd
WGS
Willmann
Wyant
xclip
xxxx
XYZ

