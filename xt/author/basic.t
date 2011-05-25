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

plan tests => 5;

diag 'Things needed for authortest';

my $file = 'data/iss.tle';
ok -f $file, "$file found"
    or diag 'See t/tle_pass.t for where to get the data';
require_ok 'Date::Manip';
require_ok 'Test::MockTime';
require_ok 'Test::Perl::Critic';
require_ok 'Test::Without::Module';


1;

# ex: set textwidth=72 :
