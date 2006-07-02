#!/usr/local/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use File::Spec;
use Test;

our $VERSION = '0.001';

#	We may need IO::String for the test. If we do, make sure it
#	is available. If it is not, skip everything.

my $gblskip = $] >= 5.008 && $Config{useperlio} ? '' : do {
    eval "use IO::String";
    $@ ? "IO::String needed but not available." : '';
    };

#	Set up the testing hook in satpass.
# >>>	This interface is undocumented, and unsupported except for its
# >>>	use in this test script.

no warnings qw{once};
$Astro::satpass::Test::Hook = \&tester;
use warnings qw{once};

#	Initialize.

my $data = '';		# Test data;
my $failure;		# Notes to output if the next test fails.
my @save;		# Storage for testers.
my $skip;		# Skip indicator
my $test = 0;		# Test number;

#	Make a pass through the <DATA> to figure out how many tests
#	there are. Tell the Test package how many.

my $start = tell (DATA);
while (<DATA>) {$test++ if m/^\s*-test\b/}
seek (DATA, $start, 0);
plan tests => $test;

#	We start from test 1 (since we increment before use).

$test = 0;

#	Set up the command arguments and 'do' the satpass script. All
#	further work is done by tester() when the script calls it.

local @ARGV = ('-filter', -initialization_file => File::Spec->devnull ());
my $script = File::Spec->catfile (qw{bin satpass});
if (-e $script) {
    $skip = $gblskip;
    do $script;
    print $@ if $@;
    }
  else {
    $skip = $gblskip = "Cannot find $script";
    1 while defined (tester (undef, '', ''));
    }

#	not_available(module ...) is a utility to determine whether the
#	given modules are available. If so, it loads them. If not, it
#	returns a message for the first module that can not be loaded.

sub not_available {
foreach my $module (@_) {
    eval "use $module";
    return "Module $module can not be loaded." if $@;
    }
return '';
}

#	not_reachable($url ...) is a utilty to determine whether the given
#	URLs are reachable. If so, it returns false. If not, it returns
#	a suitable message. Makes use of LWP::UserAgent, so may return
#	the results of not_available ('LWP::UserAgent').

sub not_reachable {
my $ok = not_available ('LWP::UserAgent');
return $ok if $ok;
my $ua = LWP::UserAgent->new () or return "Cannot instantiate LWP::UserAgent.\n$@";
foreach my $url (@_) {
    my $resp = $ua->get ($url);
    return $resp->status_line unless $resp->is_success;
    }
return '';
}

#	tester() is the test callback. It is called whenever the
#	satpass script wants top-level input. The arguments are the
#	handle used for test I/O (God knows what you would do with
#	this), the _previous_ input line, all output since the previous
#	input was done, and the exception generated (or undef if none).
#	It returns the next line of input, or undef for end-of-file.

#	At least, that's what satpass expects of it. What it does
#	from the point of view of this script is to read the <DATA>
#	handle, parsing the file as it goes. A line that begins with
#	'-' is a test directive; these will be documented in-line.
#	Empty lines and lines beginning with '#' are ignored.
#	Any thing else is returned intact to the caller.

#	The test mechanism relies on the values of four local
#	variables:
#	    $data is the expected output of the test, though you
#		will find it is used for other purposes as well.
#	    $output is the output from the satpass script, which
#		was passed by the caller. There are a couple
#		mechanisms to replace this by other data.
#	    $except is the exception encountered, if any, which
#		was passed from the caller.
#	    $skip is the skip indicator.
#	All tests are of the form skip ($skip, $output eq $data).
#	That is, they are skipped if the $skip indicator is true,
#	otherwise they are true if $output eq $data.

sub tester {
my ($handle, $input, $output, $except) = @_;
##print "foo> $input" if $input;
##print $output if $output;
while (<DATA>) {
    chomp;
    s/^\s+//;
    s/\s+$//;
    next unless $_;
    next if m/^#/;
    m/^-/ or return "$_\n";

#	We support here documents in directives. The syntax is
#	pretty much the same as Perl's, except the indicator may
#	not be quoted, and we don't do interpolation.

    s|<<(.*)|| and do {
	my $flag = ($1 || '') . "\n";
	my $buffer = $_ . "\n";
	while (<DATA>) {
	    $_ eq $flag and do {$flag = undef; last};
	    $buffer .= $_;
	    }
	die <<eod if defined $flag;
Error - Failed to find end of here document '<<$flag' before EOF.
eod
	$_ = $buffer;
	};

#	-data loads the rest of the text into  $data.

    s/-data\b\s*//m and do {$data = $_; next};

#	-fail specifies a note to be output if the next test fails.

    s/-fail\b\s*//m and do {$failure = $_; next};

#	-read reads the named file into $output. The presumption is
#	that we're testing output redirected to a file.

    s/-read\b\s*//m and do {
	my $fh;
	open ($fh, '<', File::Spec->catfile (cwd, $_));
	local $/ = undef;
	$output = <$fh>;
	next;
	};

#	-result evals the rest of the line, placing the output into
#	$output. The presumption is that we're doing some computation
#	to determine the actual results of the test.

    s/-result\b\s*//m and do {$output = eval $_; die $@ if $@; next};

#	-skip evals the rest of the line, placing the output into the
#	$skip variable. This will _not_ override any global
#	considerations that force the whole shebang to be skipped.

    s/-skip\b\s*//m and do {$skip = $gblskip || eval $_; die $@ if $@; next};

#	-test actually performs the test. The rest of the line is an
#	optional title for the test. Note that if $except is defined,
#	it becomes the thing we test.

    s/-test\b\s*//m and do {
	$test++;
	print "#\n";
	print $_ ? "# Test $test - $_\n" : "# Test $test\n";
##	$data =~ s/^\s*\n//m;
	chomp $data;
	print $data !~ m/\n/g ?
	    "#      Expected: $data\n" :
	   ("#      Expected:\n", map {"#         $_\n"} split '\n', $data);
	$output = $except if defined $except;
	$output =~ s/^\s*\n//m;
	chomp $output;
	print $output !~ m/\n/g ?
	    "#           Got: $output\n" :
	   ("#           Got:\n", map {"#         $_\n"} split '\n', $output);
	skip ($skip, $data eq $output);
	warn sprintf "\n\n$failure\n\n", $test
	    unless $skip || $data eq $output || !$failure;
	$failure = undef;
	next;
	};

#	-unlink unlinks the named file. It would be nice if there were
#	automatic cleanup, but there is not.

    s/-unlink\b\s*//m and do {unlink File::Spec->catfile (cwd, $_); next};

#	-write writes the content of $data to the named file. It's
#	$data because I figured it could always be reset before the
#	next -test, but $output once clobbered is gone for good.
#	Interestingly, in the first use of this (testing the source
#	command) the text written to the file was also what I wanted
#	to test the results against, but I can't say I planned that.

    s/-write\b\s*//m and do {
	my $fh;
	open ($fh, '>', File::Spec->catfile (cwd, $_));
	print $fh $data;
	next;
	};

#	If we get here, die complaining of an unknown directive.

    die <<eod;
Error - Unknown directive: $_
eod

    }

#	If we run out of <DATA>, we return undef to request the script
#	to exit.

return undef;
}
__END__

st get direct
-data st set direct ''
-test st get direct

st set direct 1
st get direct
-data st set direct 1
-test st set direct 1

set horizon 10
show horizon
-data set horizon 10
-test set horizon 10

macro
-data
-test macro listing (should be empty)

macro foo 'set horizon 20'
macro
-data macro foo 'set horizon 20'
-test macro definition

foo
show horizon
-data set horizon 20
-test macro 'foo' execution

macro foo 'localize horizon' 'set horizon 10' 'show horizon'
-data <<eod
macro foo 'localize horizon' \
    'set horizon 10' \
    'show horizon'
eod
macro
-test macro 'foo' redefinition

foo
-data set horizon 10
-test redefined macro 'foo' execution

show horizon
-data set horizon 20
-test localization of horizon

-skip $^O eq 'darwin' ? '' : "Skipped under $^O"

set horizon 30
show horizon -clipboard
-result $^O eq 'darwin' ? `pbpaste` : ''
-data set horizon 30
-test redirect to clipboard (Mac OS X only)

-skip ''

set horizon 15
-unlink test.tmp
show horizon >test.tmp
-data set horizon 15
-read test.tmp
-test redirect to file

-data <<eod
set location '1600 Pennsylvania Ave NW Washington DC 20502'
set latitude 38.898748
set longitude -77.037684
set height 16.68
eod
-write test.tmp
source test.tmp
show location latitude longitude height
-test source file

foo >test.tmp
-read test.tmp
-data set horizon 10
-test redirect macro output to file

-unlink test.tmp

macro foo
macro
-data
-test macro deletion

foo
-data Error - Verb 'foo' not recognized.
-test make sure macro can not be executed

-skip -d 'fubar' ? 'Directory fubar exists' : ''
cd fubar
-data <<eod
Error - Can not cd to fubar
        No such file or directory
eod
-test change directory (bad directory name)

-skip <<eod
$save[0] = getcwd or die "Can not get current directory\n";
-d 't' ? '' : 'Directory t does not exist'
eod
cd t
-result <<eod
$save[1] = getcwd or die "Can not get current directory\n";
chdir $save[0];
$save[0] eq $save[1] ? 'Failed to change directory' : 'Changed directory to t'
eod
-data Changed directory to t
-test change directory

-skip ''

set tz GMT
almanac '01-Jul-2006 midnight'
-data <<eod
Location: 1600 Pennsylvania Ave NW Washington DC 20502
          Latitude 38.8987, longitude -77.0377, height 17 m
Sat 01-Jul-2006
00:37:32 Sunset
01:09:26 End civil twilight (-6 degrees)
03:54:04 Moon set
05:11:56 Local midnight
09:14:33 Begin civil twilight (-6 degrees)
09:46:27 Sunrise
15:26:28 Moon rise
17:12:02 Local noon
21:55:25 Moon transits meridian
eod
-test almanac function

set horizon 0
macro foo 'set horizon $1'
foo 10
show horizon
-data set horizon 10
-test macro parameter passing

macro foo 'set horizon "${1:-20}"'
foo
show horizon
-data set horizon 20
-test macro parameter defaulting

macro foo 'set horizon "${1:?You must supply a value}"'
foo
-data You must supply a value
-test macro missing paramater message

macro foo 'local twilight' 'set twilight ${1:=30}' 'set horizon $1'
foo
show horizon
-data set horizon 30
-test macro parameter defaulting (sticky)

macro foo 'set horizon ${1:+40}'
foo 20
show horizon
-data set horizon 40
-test macro parameter overriding

-skip not_available ('SOAP::Lite') || not_reachable ('http://rpc.geocoder.us/')

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
at latitude 38.898748 longitude -77.037684 by hand.
eod
-data set height 16.68
-test fetch height in continental U.S. from http://gisdata.usgs.gov/

set country ca
set location '80 Wellington Street Ottawa ON'
set latitude 45.423388
set longitude -75.697786
set height 0
height
-data set height 82.00
-fail <<eod
Test %d may fail due to a database problem on http://gisdata.usgs.gov/
or due to a change in the interface specification. If you want to
distinguish between the two, visit that site and look up the height
at latitude 45.423388 longitude -75.697786 by hand.

This test may also occasionally fail because http://gisdata.usgs.gov/
returned zero for the height. I consider this to be a server bug,
not a bug in satpass.
eod
-test fetch height in Canada from http://gisdata.usgs.gov/

-skip ''
