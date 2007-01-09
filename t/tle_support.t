use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::TLE::Iridium;
use Test;

our $VERSION = '0.001';

plan tests => 31;

my $test = 0;

my ($tle, $action);
$action = 'initially';
foreach (
	[items => 92],
	[status => 'clear'],
	[items => 0],
	[status => add => 22222, iridium => ''],
	[items => 1],
	[status => add => 33333, iridium => '?'],
	[new => id => 11111],
	[class => 'Astro::Coord::ECI::TLE'],
	[can_flare => 0],
	[rebless => 'iridium'],
	[class => 'Astro::Coord::ECI::TLE::Iridium'],
	[can_flare => 1],
	['rebless'],
	[class => 'Astro::Coord::ECI::TLE'],
	[can_flare => 0],
	[set => id => 22222],
	[class => 'Astro::Coord::ECI::TLE::Iridium'],
	[can_flare => 1],
	[set => id => 33333],
	[class => 'Astro::Coord::ECI::TLE::Iridium'],
	[can_flare => 0],
	[new => id => 22222],
	[class => 'Astro::Coord::ECI::TLE::Iridium'],
	[new => reblessable => 0, id => 22222],
	[class => 'Astro::Coord::ECI::TLE'],
	[set => reblessable => 1],
	[class => 'Astro::Coord::ECI::TLE::Iridium'],
	[rebless => 'tle'],
	[class => 'Astro::Coord::ECI::TLE'],
	['rebless'],
	[class => 'Astro::Coord::ECI::TLE::Iridium'],
	[set => id => 11111],
	[class => 'Astro::Coord::ECI::TLE'],
	[is_model_attribute => reblessable => 0],
	[is_model_attribute => horizon => 0],
	[is_model_attribute => status => 0],
	[is_model_attribute => bstardrag => 1],
	[is_model_attribute => meananomaly => 1],
	[is_model_attribute => id => 0],
	[is_model_attribute => name => 0],
	[is_valid_model => model => 1],
	[is_valid_model => null => 1],
	[is_valid_model => sgp4 => 1],
	[is_valid_model => sdp4 => 1],
	[is_valid_model => pdq4 => 0],
	) {
    my ($method, @args) = @$_;
    my ($what, $got);
    if ($method eq 'can_flare') {
	$what = 'value of';
	$action = "\$tle->can_flare ()";
	$got = $tle->can_flare () || 0;
    } elsif ($method eq 'class') {
	$what = 'class';
	$got = ref $tle;
    } elsif ($method eq 'is_model_attribute') {
	$what = 'value of';
	my $arg = shift @args;
	$action = "TLE->is_model_attribute ('$arg')";
	$got = Astro::Coord::ECI::TLE->is_model_attribute ($arg) || 0;
    } elsif ($method eq 'is_valid_model') {
	$what = 'value of';
	my $arg = shift @args;
	$action = "TLE->is_valid_model ('$arg')";
	$got = Astro::Coord::ECI::TLE->is_valid_model ($arg) ? 1 : 0;
    } elsif ($method eq 'items') {
	$what = 'status items';
	my @got = Astro::Coord::ECI::TLE->status ('show');
	$got = @got;
    } elsif ($method eq 'new') {
	$tle = Astro::Coord::ECI::TLE->new (@args);
    } elsif ($method eq 'rebless') {
	$tle->rebless (@args);
    } elsif ($method eq 'set') {
	$tle->set (@args);
    } elsif ($method eq 'status') {
	Astro::Coord::ECI::TLE->status (@args);
    }
    if (defined $what) {
#	Test
	my $want = shift @args;
	$test++;
	print <<eod;
#
# Test $test - $what $action
#    Expect: $want
#       Got: $got
eod
	$want =~ m/\D/ ? ok ($want eq $got) : ok ($want == $got);
    } else {
	$action = 'after TLE->' . arglist ($method => @args);
    }
}

sub arglist {
    my $method  = shift;
    my @fmt;
    for (my $inx = 0; $inx < @_; $inx += 2) {
	my $incr = $inx + 1;
	push @fmt, $incr >= @_ ? "'$_[$inx]'" : "$_[$inx] => " .
	    ($_[$incr] =~ m/\D/ || !$_[$incr] ? "'$_[$incr]'" : $_[$incr]); 
    }
    "$method (" . join (', ', @fmt) . ')';
}
