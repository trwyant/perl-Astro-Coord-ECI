use strict;
use warnings;

my $ok;
BEGIN {
    eval "use Test::More";
    if ($@) {
	print <<eod;
1..0 # skip Test::More required to test POD validity.
eod
	exit;
    }
    eval "use Test::Pod 1.00";
    if ($@) {
	print <<eod;
1..0 # skip Test::Pod 1.00 or higher required to test POD validity.
eod
	exit;
    }
}

all_pod_files_ok ();
