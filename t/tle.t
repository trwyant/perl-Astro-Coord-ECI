#!/usr/local/bin/perl

use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use List::Util qw{max};
use Test;

BEGIN {plan tests => 150};

my @data;
my $hdlr = sub {};
my $tle;
my $model;
my $test = 0;
my @title = qw{X Y Z XDOT YDOT ZDOT};
my @mindenom = (2000, 2000, 2000, .5, .5, .5);

my %action = (
    data => sub {@data = (); $tle = undef; sub {push @data, $_[0]}},
    rem => sub {print "#\n"; sub {print "# $_[0]\n"}},
    sgp => \&model_setup,
    sgp4 => \&model_setup,
    sgp8 => \&model_setup,
    sdp4 => \&model_setup,
    sdp8 => \&model_setup,
    );

while (<DATA>) {
    chomp;
    m/^\s*$/ and next;
    m/^\s*#/ and next;
    s/^\s+//;
    s/\s+$//;
    m/^\s*-(\S+)/ and do {
	$hdlr = $action{lc $1} or die <<eod;
Error - Unrecognized action -$1
eod
	$hdlr = $hdlr->(lc $1);
	next;
	};
    $hdlr->($_);
    }

sub model {
my ($tsince, @std) = split '\s+', $_[0];
$tsince += 0;
my $time = $tle->get ('epoch') + $tsince * 60;
## my @calc = $tle->$model ($time);
my @calc = $tle->$model ($time)->eci;
foreach (my $iter8 = 0; $iter8 < 6; $iter8++) {
    $test++;
    print "# Test $test: tsince = $tsince. $title[$iter8] std: $std[$iter8], calc $calc[$iter8]\n";
    my $denom = max (abs ($std[$iter8]), $mindenom[$iter8]);
    ok (abs (($std[$iter8] - $calc[$iter8]) / $denom) < .00001);
    }
}

sub model_setup {
$tle ||= (Astro::Coord::ECI::TLE->parse (@data))[0];
$model = $_[0];
print <<eod;
#
# **** $model ****
# $data[0]
# $data[1]
eod
\&model;
}
__END__

-rem

The following tests are as described in Spacetrack Report no. 3,
Models for Propagation of NORAD Element Sets

-data
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105

-sgp
# TSINCE X Y Z XDOT YDOT ZDOT
0. 2328.96594238 -5995.21600342 1719.97894287 2.91110113 -0.98164053 -7.09049922
360.00000000 2456.00610352 -6071.94232177 1222.95977784 2.67852119 -0.44705850 -7.22800565
720.00000000 2567.39477539 -6112.49725342 713.97710419 2.43952477 0.09884824 -7.31889641
1080.00000000 2663.03179932 -6115.37414551 195.73919105 2.19531813 0.65333930 -7.36169147
1440.00000000 2742.85470581 -6079.13580322 -328.86091614 1.94707947 1.21346101 -7.35499924

-sgp4
# TSINCE X Y Z XDOT YDOT ZDOT
0. 2328.97048951 -5995.22076416 1719.97067261 2.91207230 -0.98341546 -7.09081703
360.00000000 2456.10705566 -6071.93853760 1222.89727783 2.67938992 -0.44829041 -7.22879231
720.00000000 2567.56195068 -6112.50384522 713.96397400 2.44024599 0.09810869 -7.31995916
1080.00000000 2663.09078980 -6115.48229980 196.39640427 2.19611958 0.65241995 -7.36282432
1440.00000000 2742.55133057 -6079.67144775 -326.38095856 1.94850229 1.21106251 -7.35619372

-sgp8
# TSINCE X Y Z XDOT YDOT ZDOT
0. 2328.87265015 -5995.21289063 1720.04884338 2.91210661 -0.98353850 -7.09081554
360.00000000 2456.04577637 -6071.90490722 1222.84086609 2.67936245 -0.44820847 -7.22888553
720.00000000 2567.68383789 -6112.40881348 713.29282379 2.43992555 0.09893919 -7.32018769
1080.00000000 2663.49508667 -6115.18182373 194.62816810 2.19525236 0.65453661 -7.36308974
1440.00000000 2743.29238892 -6078.90783691 -329.73434067 1.94680957 1.21500109 -7.35625595

-data
1 11801U          80230.29629788  .01431103  00000-0  14311-1
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848

-sdp4
# TSINCE X Y Z XDOT YDOT ZDOT
0. 7473.37066650 428.95261765 5828.74786377 5.10715413 6.44468284 -0.18613096
360.00000000 -3305.22537232 32410.86328125 -24697.17675781 -1.30113538 -1.15131518 -0.28333528
720.00000000 14271.28759766 24110.46411133 -4725.76837158 -0.32050445 2.67984074 -2.08405289
1080.00000000 -9990.05883789 22717.35522461 -23616.89062501 -1.01667246 -2.29026759 0.72892364
1440.00000000 9787.86975097 33753.34667969 -15030.81176758 -1.09425066 0.92358845 -1.52230928

-sdp8
# TSINCE X Y Z XDOT YDOT ZDOT
0. 7469.47631836 415.99390792 5829.64318848 5.11402285 6.44403201 -0.18296110
360.00000000 -3337.38992310 32351.39086914 -24658.63037109 -1.30200730 -1.15603013 -0.28164955
720.00000000 14226.54333496 24236.08740234 -4856.19744873 -0.33951668 2.65315416 -2.08114153
1080.00000000 -10151.59838867 22223.69848633 -23392.39770508 -1.00112480 -2.33532837 0.76987664
1440.00000000 9420.08203125 33847.21875000 -15391.06469727 -1.11986055 0.85410149 -1.49506933