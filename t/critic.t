package main;

use strict;
use warnings;

use File::Spec;

BEGIN {
    unless ($ENV{DEVELOPER_TEST}) {
	print "1..0 # skip Environment variable DEVELOPER_TEST not set.\n";
	exit;
    }
    eval {
	require Test::More;
	Test::More->VERSION(0.40);
	Test::More->import();
    };
    if ($@) {
	print "1..0 # skip Test::More required to criticize code.\n";
	exit;
    }
    eval {
	require Test::Perl::Critic;
	Test::Perl::Critic->import(
	    -profile => File::Spec->catfile(qw{t perlcriticrc})
	);
    };
    if ($@) {
	print "1..0 # skip Test::Perl::Critic required to criticize code.\n";
	exit;
    }
}

all_critic_ok('lib');

1;
