package main;

use strict;
use warnings;

use ExtUtils::Manifest qw{maniread};
use Test;

my $manifest = maniread ();

my @check;
foreach (sort keys %$manifest) {
    (m/^bin\b/ || m/^eg\b/) and next;
    push @check, $_;
}

plan (tests => scalar @check);

my $test = 0;
foreach my $file (@check) {
    my $skip = $file =~ m/^bin\b/ ? 'Intended as an executable' :
    	$file =~ m/^eg\b/ ? 'Examples are not installed' : '';
    $test++;
    print "# Test $test - $file\n";
    open (my $fh, '<', $file) or die "Unable to open $file: $!\n";
    local $_ = <$fh>;
    close $fh;
    my @stat = stat $file;
    skip ($skip, !($stat[2] & oct(111) || m/^#!.*perl/));
}

1;
