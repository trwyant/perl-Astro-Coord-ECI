use strict;
use warnings;

## use Astro::SpaceTrack;
use POSIX qw{strftime};
use Test;
use Time::Local;

eval {require LWP::UserAgent};
if ($@) {
    print "1..0 # skip LWP::UserAgent not available\n";
    exit;
}

plan tests => 4;

use constant TFMT => '%d-%b-%Y %H:%M:%S GMT';

my %mth;
{	# Local symbol block
    my $inx = 0;
    foreach my $nam (qw{jan feb mar apr may jun jul aug sep oct nov dec}) {
	$mth{$nam} = $inx++;
	}
    }

my $fail = 0;
my $test = 0;
my $ua = LWP::UserAgent->new ();
my $asof = timegm (0, 0, 19, 4, 05, 108);

foreach (["Mike McCants' Iridium status",
	'http://www.io.com/~mmccants/tles/iridium.html',
	$asof,
	mccants => <<eod],
<html>
<head>
<title>
Status for Iridium payloads
</title>
</head>

<body>
<h2><center>Status for Iridium payloads</center></h2>
<p>
<pre>
Iridium status as of Jan. 22, 2008
==================================

Iridiums not listed in the following table are thought to be stable
in orbit and capable of generating flares.

Nov. 29, 2000: Iridium 79 (NCat 25470) decayed.
Dec. 30, 2000: Iridium 85 (NCat 25529) decayed.
May 5, 2001:   Iridium 48 (NCat 25107) decayed.
Jan. 31, 2002: Iridium 27 (NCat 24947) decayed.
Mar. 11, 2003: Iridium 9 (NCat 24838) decayed.
Jan. 29, 2004: Spacecom exchanged the names for objects 25577
               (now Iridium 20) and 25578 (now Iridium 11).
Aug. 2003:     Iridium 38 failed.
June 2004:     Iridiums 2, 38, 69 and 73 were changed to "failed".
Apr. 24, 2005: Iridium 16 has been replaced by Iridium 86.
June 14, 2005: Iridium 16 has been seen tumbling - changed to "tum".
June 2005:     Iridium 98 has changed its inclination so that it will
               drift between planes.
Aug. 2005:     Iridium 77 has been maneuvered into the orbital spot
               for Iridium 17.  Presumably, Iridium 17 has failed.
Oct. 2005:     Iridium 90 has changed its inclination so that it will
               drift between planes.
Jan. 2006:     Spacecom has switched the names for Iridium 91 and Iridium 90
Jan. 10, 2006: Iridium 74 has been moved into a lower orbit and Iridium 21
               was moved to take its place.
Jan. 10, 2007: From January 5 to January 9, 2007, Iridium 97 was moved from
               its lower orbit to an orbit "next to" Iridium 36.
Mar. 6, 2007:  Iridium 36 has not had an orbit maintenance maneuver since
               January and was observed to flash, so I assume it has failed.
May 4, 2007:   Iridium 98 has changed its inclination so that it is now
               a spare in its new plane.
Jan. 22, 2008: Iridium 90 has changed its inclination so that it is now
               a spare in its new plane.

 NCat    Name           Status   Comment
 24836   Iridium 914    tum      Failed; was called Iridium 14
 24841   Iridium 16     tum      Removed from operation about April 7, 2005
 24842   Iridium 911    tum      Failed; was called Iridium 11
 24870   Iridium 17     tum?     Failed in August 2005?
 24871   Iridium 920    tum      Failed; was called Iridium 20
 24873   Iridium 921    tum      Failed; was called Iridium 21
 24967   Iridium 36     tum      Failed in January 2007
 25043   Iridium 38     tum      Failed in August 2003
 25078   Iridium 44     tum      Failed
 25105   Iridium 24     tum      Failed
 25262   Iridium 51     ?        Spare
 25319   Iridium 69     tum      Failed
 25320   Iridium 71     tum      Failed
 25344   Iridium 73     tum      Failed
 25345   Iridium 74     ?        Removed from operation about January 8, 2006
 25527   Iridium 2      tum      Failed
 25577   Iridium 20              was called Iridium 11
 25578   Iridium 11     ?        Spare   was called Iridium 20
 25777   Iridium 14     ?        Spare   was called Iridium 14A
 25778   Iridium 21              Replaced Iridium 74   was called Iridium 21A
 27372   Iridium 91     ?        Spare   was called Iridium 90
 27373   Iridium 90     ?        Spare (new plane Jan. 2008)   was called Iridium 91
 27374   Iridium 94     ?        Spare
 27375   Iridium 95     ?        Spare
 27376   Iridium 96     ?        Spare
 27450   Iridium 97              Replaced Iridium 36 on Jan. 10, 2007
 27451   Iridium 98     ?        Spare (new plane May 2007)

Status  Meaning
------  -------
blank   Object is operational

tum     tumbling - no flares, but flashes seen on favorable transits.

?       not at operational altitude - flares may be unreliable.

man     maneuvering, at least slightly. Flares may be unreliable and the
        object may be early or late against prediction.

===================================

Iridium Constellation Status information by Rod Sladen:
<a href="http://www.rod.sladen.org.uk/iridium.htm">Iridium Status</a>

===================================
</pre>
</body>
</html>
eod
	["T. S. Kelso's Iridium list",
	'http://celestrak.com/SpaceTrack/query/iridium.txt',
	$asof,
	kelso => <<eod],
24792IRIDIUM 8 [+]
24793IRIDIUM 7 [+]
24794IRIDIUM 6 [+]
24795IRIDIUM 5 [+]
24796IRIDIUM 4 [+]
24836IRIDIUM 914 [-]
24837IRIDIUM 12 [+]
24839IRIDIUM 10 [+]
24840IRIDIUM 13 [+]
24841IRIDIUM 16 [-]
24842IRIDIUM 911 [-]
24869IRIDIUM 15 [+]
24870IRIDIUM 17 [-]
24871IRIDIUM 920 [-]
24872IRIDIUM 18 [+]
24873IRIDIUM 921 [-]
24903IRIDIUM 26 [+]
24904IRIDIUM 25 [+]
24905IRIDIUM 46 [+]
24906IRIDIUM 23 [+]
24907IRIDIUM 22 [+]
24925DUMMY MASS 1 [-]
24926DUMMY MASS 2 [-]
24944IRIDIUM 29 [+]
24945IRIDIUM 32 [+]
24946IRIDIUM 33 [+]
24948IRIDIUM 28 [+]
24949IRIDIUM 30 [+]
24950IRIDIUM 31 [+]
24965IRIDIUM 19 [+]
24966IRIDIUM 35 [+]
24967IRIDIUM 36 [-]
24968IRIDIUM 37 [+]
24969IRIDIUM 34 [+]
25039IRIDIUM 43 [+]
25040IRIDIUM 41 [+]
25041IRIDIUM 40 [+]
25042IRIDIUM 39 [+]
25043IRIDIUM 38 [-]
25077IRIDIUM 42 [+]
25078IRIDIUM 44 [-]
25104IRIDIUM 45 [+]
25105IRIDIUM 24 [-]
25106IRIDIUM 47 [+]
25108IRIDIUM 49 [+]
25169IRIDIUM 52 [+]
25170IRIDIUM 56 [+]
25171IRIDIUM 54 [+]
25172IRIDIUM 50 [+]
25173IRIDIUM 53 [+]
25262IRIDIUM 51 [S]
25263IRIDIUM 61 [+]
25272IRIDIUM 55 [+]
25273IRIDIUM 57 [+]
25274IRIDIUM 58 [+]
25275IRIDIUM 59 [+]
25276IRIDIUM 60 [+]
25285IRIDIUM 62 [+]
25286IRIDIUM 63 [+]
25287IRIDIUM 64 [+]
25288IRIDIUM 65 [+]
25289IRIDIUM 66 [+]
25290IRIDIUM 67 [+]
25291IRIDIUM 68 [+]
25319IRIDIUM 69 [-]
25320IRIDIUM 71 [-]
25342IRIDIUM 70 [+]
25343IRIDIUM 72 [+]
25344IRIDIUM 73 [-]
25345IRIDIUM 74 [S]
25346IRIDIUM 75 [+]
25431IRIDIUM 3 [+]
25432IRIDIUM 76 [+]
25467IRIDIUM 82 [+]
25468IRIDIUM 81 [+]
25469IRIDIUM 80 [+]
25471IRIDIUM 77 [+]
25527IRIDIUM 2 [-]
25528IRIDIUM 86 [+]
25530IRIDIUM 84 [+]
25531IRIDIUM 83 [+]
25577IRIDIUM 20 [+]
25578IRIDIUM 11 [S]
25777IRIDIUM 14 [S]
25778IRIDIUM 21 [+]
27372IRIDIUM 91 [S]
27373IRIDIUM 90 [S]
27374IRIDIUM 94 [S]
27375IRIDIUM 95 [S]
27376IRIDIUM 96 [S]
27450IRIDIUM 97 [+]
27451IRIDIUM 98 [S]
eod
	) {
    my ($what, $url, $expect, $file, $data) = @$_;
    $test++;
    my ($skip, $rslt, $got, $dt) = parse_date ($url);
    $dt ||= 0;
    print <<eod;
#
# Test $test: Date of $what
#       URL: $url
#    Expect: before @{[strftime TFMT, gmtime $expect]}
#       Got: $got
eod
    skip ($skip, $dt < $expect);

    $test++;
    $skip ||= 'No comparison data provided' unless $data;
    if ($data && $rslt) {
	$got = $rslt->content ();
	1 while $got =~ s/\015\012/\n/gm;
	$skip = '';
	}
      else {
	$got = $skip ||= 'No known reason';
	}
    print <<eod;
#
# Test $test: Content of $what
#       URL: $url
eod
    skip ($skip, $got eq $data);
    unless ($skip || $got eq $data) {
	open (HANDLE, ">$file.expect");
	print HANDLE $data;
	open (HANDLE, ">$file.got");
	print HANDLE $got;
	warn <<eod;
#
# Expected and gotten information written to $file.expect and
# $file.got respectively.
#
eod
	}
    }

warn <<eod if $fail;
#
# Failures in this test script simply mean that the Iridium status
# information shipped with the package may be out of date.
#
eod

sub parse_date {
my ($url) = @_;
my $rslt = $ua->get ($url);
$rslt->is_success or return ($rslt->status_line);
my $got = $rslt->header ('Last-Modified') or
    return ('Last-Modified header not returned', $rslt);
my ($day, $mon, $yr, $hr, $min, $sec) =
    $got =~ m/,\s*(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)/ or
    return ('Unable to parse Last-Modified header', $rslt);
defined (my $mn = $mth{lc $mon}) or
    return ('Invalid month in Last-Modified header', $rslt);
return (undef, $rslt, $got, timegm ($sec, $min, $hr, $day, $mn, $yr));
}

