use strict;
use warnings;

my $ok;
BEGIN {
eval "use Test::More";
$ok = !$@;
}

if ($ok) {
    eval "use Test::Pod::Coverage 1.00";
    plan skip_all => "Test::Pod::Coverage 1.00 required to test POD coverage." if $@;
    all_pod_coverage_ok ({coverage_class => 'Pod::Coverage::CountParents'});
    }
  else {
    print <<eod;
1..1
ok 1 # skip Test::More required for testing POD coverage.
eod
    }
