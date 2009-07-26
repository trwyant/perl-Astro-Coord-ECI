package main;

use Test::More 0.40;

use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::TLE::Set;
use Time::Local;

plan('no_plan');
# plan(tests => 3);

my $epoch = timelocal(0, 0, 0, 1, 3, 109);	# April 1 2009;
my $backdate = Astro::Coord::ECI::TLE->new(
    id => 11111, epoch => $epoch);
my $nobackdate = Astro::Coord::ECI::TLE->new(
    id => 11111, epoch => $epoch, backdate => 0);
my $asof = $epoch - 86400;
my $effective = Astro::Coord::ECI::TLE->new(
    id => 11111, epoch => $epoch, effective => $asof);
my $past = $asof - 86400;

is($backdate->max_effective_date(), undef,
    '$backdate->max_effective_date() is undef');
is($nobackdate->max_effective_date(), $epoch,
    '$nobackdate->max_effective_date() is $epoch');
is($effective->max_effective_date(), $asof,
    '$effective->max_effective_date() is $asof');

is($backdate->max_effective_date($past), $past,
    '$backdate->max_effective_date($past) is $past');
is($nobackdate->max_effective_date($past), $epoch,
    '$nobackdate->max_effective_date($past) is $epoch');
is($effective->max_effective_date($past), $asof,
    '$effective->max_effective_date($past) is $asof');

is($backdate->max_effective_date($asof), $asof,
    '$backdate->max_effective_date($asof) is $asof');
is($nobackdate->max_effective_date($asof), $epoch,
    '$nobackdate->max_effective_date($asof) is $epoch');
is($effective->max_effective_date($asof), $asof,
    '$effective->max_effective_date($asof) is $asof');

my ($set) = Astro::Coord::ECI::TLE::Set->aggregate($backdate, $effective);

is($set->max_effective_date($past), $asof,
    '$set->max_effective_date($past) is $asof');
is($set->select(), $effective,
    '$set->max_effective_date($past) selects $effective');
is($set->max_effective_date($asof), $asof,
    '$set->max_effective_date($asof) is $asof');
is($set->select(), $effective,
    '$set->max_effective_date($asof) selects $effective');
is($set->max_effective_date($epoch), $epoch,
    '$set->max_effective_date($epoch) is $epoch');
is($set->select(), $backdate,
    '$set->max_effective_date($epoch) selects $backdate');

1;
