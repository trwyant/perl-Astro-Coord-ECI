package main;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing()
BEGIN {
    eval {
	require Test::Pod;
	Test::Pod->VERSION (1.00);
	Test::Pod->import();
	1;
    } or do {
	print <<eod;
1..0 # skip Test::Pod 1.00 or higher required to test POD validity.
eod
	exit;
    };
}

all_pod_files_ok ();

1;
