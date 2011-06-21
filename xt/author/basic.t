package main;

use 5.006002;

use strict;
use warnings;

BEGIN {
    my $test_more;
    eval {
	$test_more = __LINE__ + 1;
	require Test::More;
	Test::More->VERSION( 0.52 );
	Test::More->import();
	1;
    } or do {
	( my $err = $@ ) =~ s/ (?<= \n ) (?= . ) /#   /smx;
	print "1..1\n";
	print "not ok 1 - require Test::More 0.52;\n",
	"#   Failed test 'require Test::More 0.52;'\n",
	"#   at ", __FILE__, ' line ', $test_more, "\n",
	"#   Error: $err";
	exit;
    }
}



plan tests => 8;

diag 'Things needed for authortest';

require_ok 'File::Spec';

{
    my $dir = $ENV{ASTRO_COORD_ECI_TLE_DIR};
    $dir
	and -d $dir
	or eval {
	require File::HomeDir;
	$dir = File::HomeDir->my_dist_config(
	    'Astro-Coord-ECI-TLE-Dir' );
    };

    ok $dir, 'TLE directory found'
	or diag 'See t/tle_pass_extra.t for where the TLE data should go';

    my $file = File::Spec->catfile( $dir, 'pass_extra.tle' );
    ok $dir && -f $file, "TLE file $file found"
	or diag 'See t/tle_pass_extra.t for what goes in this file';

}

require_ok 'Date::Manip';
require_ok 'Test::MockTime';
require_ok 'Test::Perl::Critic';
require_ok 'Test::Without::Module';
require_ok 'Time::Local';

1;

# ex: set textwidth=72 :
