package main;

use strict;
use warnings;

use File::Spec;

use Test::More 0.88;	# Because of done_testing()
BEGIN {
    eval {
	require Test::Perl::Critic;
	Test::Perl::Critic->import(
	    -profile => File::Spec->catfile(qw{ xt author perlcriticrc })
	);
	1;
    } or do {
	print "1..0 # skip Test::Perl::Critic required to criticize code.\n";
	exit;
    };
}

all_critic_ok('lib');

1;
