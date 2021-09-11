package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

BEGIN {
    local $@ = undef;
    eval {
	require Test::Pod::LinkCheck::Lite;
	Test::Pod::LinkCheck::Lite->import( ':const' );
	1;
    } or plan skip_all => 'Unable to load Test::Pod::LinkCheck::Lite';
}

Test::Pod::LinkCheck::Lite->new(
    prohibit_redirect	=> ALLOW_REDIRECT_TO_INDEX,
    # The following is temporary until the dust settles from the
    # American Astronomical Society's purchase of Willman Bell. As of
    # September 11 2021, the former's web site says materials should be
    # available on the AAS web site by the end of October.
    ignore_url		=> 'https://www.willbell.com/',
)->all_pod_files_ok(
    qw{ blib eg },
);

done_testing;

1;

# ex: set textwidth=72 :
