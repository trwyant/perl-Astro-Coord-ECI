package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::Spelling;
	Test::Spelling->import();
	1;
    } or do {
	print "1..0 # skip Test::Spelling not available.\n";
	exit;
    };
}

add_stopwords (<DATA>);

all_pod_files_spelling_ok ();

1;
__DATA__
Above's
accreted
akm
Alasdair
altazimuth
AMSAT
angulardiameter
angularvelocity
apoapsis
App
appulse
appulsed
appulsing
appulses
argumentofperigee
ascendingnode
ascensional
Astro
astrodynamics
astrometry
au
autoheight
azel
backdate
Barycentric
barycentre
BC
bissextile
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
Coord
coodinate
Coords
CPAN
dans
darwin
DateTime
datetime
de
deb
declinational
deg
degreesDminutesMsecondsS
des
distsq
DMOD
Dominik
ds
du
dualvar
dualvars
ECEF
ECI
eci
EDT
edt
edu
elementnumber
elevational
ELP
ephemeristype
Escobal
EST
exportable
ff
firstderivative
foo
Foucault
fr
Francou
Fugina
Gasparovic
gb
geocode
Geocoder
geocoder
geodesy
gmt
gmtime's
Goran
gory
Green's
Gregorian
harvard
Haversine
haversine
haversines
Hujsak
IDs
illum
illuminator
IMACAT
Imacat
ini
internet
isa
jan
jcent
jd
jday
Jenness
jul
julianday
Kazimierz
Kelso
Kelso's
lib
libnova
LLC
ls
Lune
ly
magics
Magliacane
Magliacane's
Maidenhead
magma
Mariana
max
McCants
meananomaly
meanmotion
Meeus
min
mma
mmas
Moon's
MoonPhase
MSWin
Mueller
NORAD
NORAD's
nouvelles
Obliquity
obliquity
Observatoire
OID
op
oped
orbitaux
orizuru
Palau
parametres
pbcopy
pbpaste
pc
PE
periapsis
perigee
perltime
Persei
pg
pkm
pm
pp
pre
psiprime
rad
Ramon
rcs
readonly
rebless
reblessable
reblessed
reblesses
reblessing
recessional
ref
reportable
revolutionsatepoch
Rico
rightascension
Roehric
ruggedizing
Saemundsson's
SATCAT
Satpass
satpass
SATPASSINI
SDP
sdp
secondderivative
semimajor
semiminor
SGP
sgp
SI
SIGINT
SIMBAD
Simbad
simbad
Sinnott
SKYSAT
skysat
SLALIB
Smart's
solstices
SPACETRACK
Spacetrack
STDERR
Steffen
Storable
strasbg
SunTime
Survey's
TAI
TDB
TDT
Terre
thetag
Thorfinn
timegm's
timekeeping
TIMEZONES
TLE
tle
TLEs
TT
Touze
Turbo
TWOPI
tz
uk
unreduced
URI
username
USGS
UT
UTC
VA
valeurs
Vallado
ver
webcmd
westford
WGS
Willmann
Wyant
xclip
xxxx
XYZ

