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
	chomp $data;
	print $data !~ m/\n/g ?
	    "#      Expected: $data\n" :
	   ("#      Expected:\n", map {"#         $_\n"} split '\n', $data);
	$output = $except if defined $except;
	chomp $output;
	print $output !~ m/\n/g ?
	    "#           Got: $output\n" :
	   ("#           Got:\n", map {"#         $_\n"} split '\n', $output);
	skip ($skip, $data eq $output);
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
-data
-test st get direct

st set direct 1
st get direct
-data 1
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

