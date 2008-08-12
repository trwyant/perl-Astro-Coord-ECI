use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use File::Spec;
use Test;

my $tle_file = File::Spec->catfile ('t', 'sgp4-ver.tle');
unless (-e $tle_file) {
    $ENV{AUTOMATED_TESTING}
	and bail_out ("Automated testing and $tle_file not downloaded");
    prompt ("\nTest file $tle_file needed. ",
	"Shall I download? [y/n d:n]: ") =~ m/^y/i
	or bail_out ("Skipped at tester request; $tle_file not downloaded");
    foreach (qw{File::Temp LWP::UserAgent Archive::Zip}) {
	eval "require $_; 1" or bail_out ("Unable to load $_");
    }
    my $url = 'http://celestrak.com/publications/AIAA/2006-6753/AIAA-2006-6753.zip';

    my $ua = LWP::UserAgent->new ();
    warn "\n# Fetching $url\n";
    my $rslt = $ua->get ($url);
    $rslt->is_success
	or bail_out ("Failed to fetch data: ", $rslt->status_line);

    my $fh = File::Temp->new ();
    binmode $fh;
    print $fh $rslt->content;
    seek $fh, 0, 0;

    my $member = 'sgp4-ver.tle';

    my $zip = Archive::Zip->new ();
    warn "# Reading Zip file\n";
    my $status = $zip->read ($fh->filename);
    $status == &Archive::Zip::AZ_OK
	or bail_out ("Zip data stream read error: $status");
    warn "# Extracting $member to $tle_file\n";
    $status = $zip->extractMember ($member, $tle_file);
    $status == &Archive::Zip::AZ_OK
	or bail_out ("Unable to extract Zip member $member: $status");
}

Astro::Coord::ECI::TLE->set (gravconst_r => 72);

#### my $default_tolerance = [1, 1, 1, .001, .001, .001];
my $default_tolerance = [(.00001) x 3, (.00000001) x 3];
my %object_tolerance;
while (<DATA>) {
    s/^\s+//;
    $_ or next;
    substr ($_, 0, 1) eq '#' and next;
    s/\s+$//;
    my ($oid, @toler) = split '\s+', $_;
    $oid += 0;
    $object_tolerance{$oid} = \@toler;
}

open (my $rslt, '<', 't/sgp4r.out') or die "Failed to open t/sgp4r.out: $!";
my $satnum = qr{^\s*(\d+)\s*xx\s*$}i;
my $test = 0;
{
    my $pos = tell ($rslt);
    while (<$rslt>) {
	m/$satnum/ and next;
	$test += 6;
    }
    seek ($rslt, $pos, 0);
}

plan (tests => $test);

my @satrecs;
{
    local $/ = undef;	# Slurp mode.
    open (my $fh, '<', $tle_file) or die "Failed to open $tle_file: $!";
    my $data = <$fh>;
    @satrecs = Astro::Coord::ECI::TLE->parse ($data);
}

$test = 0;
my $tle;
my $oid;
my @label = qw{X Y Z Xdot Ydot Zdot};
my @delta;
my @max_delta = (0) x 6;
while (<$rslt>) {
    if (m/$satnum/) {
	&compute_delta;
	$oid = $1 + 0;
	$tle = undef;
	foreach (@satrecs) {
	    $_->get ('id') == $oid or next;
	    $tle = $_;
	    last;
	}
	$tle or die "Unable to find OID $oid";
	@delta = (0) x 6;
    } else {
	s/\s+$//;
	s/^\s+//;
	my ($td, @want) = split '\s+', $_;
	$td += 0;
	print <<eod;
#
# OID $oid, $td minutes from epoch.
eod
	my $time = $td * 60 + $tle->get ('epoch');
	my @got = $tle->sgp4r ($time)->eci ();
	my $tolerance = $object_tolerance{$oid} || $default_tolerance;
	foreach my $inx (0 .. 5) {
	    $test++;
	    my $delta = $want[$inx] - $got[$inx];
	    print <<eod;
#
# Test $test - $label[$inx]
#    Want: $want[$inx]
#     Got: $got[$inx]
#        Delta: $delta
#    Tolerance: $tolerance->[$inx]
eod
##	    ok ($want[$inx] == $got[$inx]);
	    ok (abs ($delta) <= $tolerance->[$inx]);
	    abs ($delta) > abs ($delta[$inx]) and $delta[$inx] = $delta;
	}
    }
}
&compute_delta;
print <<eod;
#
# Maximum deltas, all OIDs:
#     @max_delta[0 .. 2]
#     @max_delta[3 .. 5]
eod

sub compute_delta {
    if (@delta) {
	print <<eod;
#
# Maximum deltas for $oid:
#     @delta[0 .. 2]
#     @delta[3 .. 5]
eod
	foreach my $inx (0 .. 5) {
	    abs ($delta[$inx]) > abs ($max_delta[$inx])
		and $max_delta[$inx] = $delta[$inx];
	}
    }
}

sub bail_out {
    print '1..0 # skip ', @_, "\n";
    warn <<eod;

This test requires file sgp4-ver.tle, which is contained in
http://celestrak.com/publications/AIAA/2006-6753/AIAA-2006-6753.zip I am
not authorized to redistribute TLEs, so I have not included this file in
the distribution. Dr. Kelso of celestrak.com _is_ authorized, but either
the user has requested that it not be downloaded, or my attempt to do so
was unsuccessful. The download requires that the web site be up and
accessable, and that you have File::Temp, LWP::UserAgent, and
Archive::Zip installed.

If the download failed for whatever reason, you can download and extract
the file yourself, placing it in the 't' subdirectory. The file has
Internet/DOS line endings (cr/lf), but Perl's digestion is robust enough
that this should not be a problem.

eod
    exit;
}

sub prompt {
    print STDERR @_;
    return unless defined (my $input = <STDIN>);
    chomp $input;
    return $input;
}

__DATA__
## 23599	1	1	1	.001	.001	.001