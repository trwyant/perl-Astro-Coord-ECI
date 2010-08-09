package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print <<eod;
1..0 # skip Test::More 0.40 or higher required.
eod
	exit;
    };
}

BEGIN {
    eval {
	require ExtUtils::Manifest;
	ExtUtils::Manifest->import( qw{ manicheck filecheck } );
	1;
    } or do {
	plan( skip_all => "ExtUtils::Manifest required" );
	exit;
    };
}

plan( tests => 2 );

is( join( ' ', manicheck() ), '', 'Missing files per manifest' );
is( join( ' ', filecheck() ), '', 'Files not in MANIFEST or MANIFEST.SKIP' );

1;
