#!/usr/bin/perl

use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker qw{WriteMakefile prompt};
use FileHandle;
use Getopt::Std;

my %opt;
getopts ('ny', \%opt) or die <<eod;
The only legal options are
  -n = answer all questions 'no'.
  -y = answer all questions 'yes'.
You may not assert both of these at once - it's too confusing.
eod

my @exe_files;
my @clean_files;
my @prereq;

print <<eod;

You have the option of installing the following executable:

  satpass is a scriptable program to predict satellite passes
    over a given observer.

Unless you are running MSWin32 or VMS (which are special-cased),
I will assume you're running some version of U*ix, and behave
accordingly.

eod

my @possible_exes = qw{satpass};
if ($opt{n}) {
    print "Because you have asserted -n, the executables will not be installed.\n\n";
    }
  elsif ($opt{y}) {
    print "Because you have asserted -y, the executables will be installed.\n\n";
    @exe_files = @possible_exes;
    }
  else {
    foreach (@possible_exes) {
	push @exe_files, $_
	    if prompt ("Do you want to install $_?", 'n') =~ m/^y/i;
	}
    }

if (@exe_files) {
    push @prereq, 'Date::Manip' => 0;
    foreach (['Astro::SpaceTrack' => 0.011, <<eod],
Optional module Astro::SpaceTrack version 0.011 or higher is needed if
you wish to retrieve orbital elements directly from Space Track or
Celestrak into the executable.
eod
	    ['IO::String' => 0, <<eod],
Optional module IO::String is needed if you wish to pass commands to
the executable on its command line or to write macros.
eod
	    ['Soap::Lite' => 0, <<eod],
Optional module Soap::Lite is needed if you wish to use Geocoder.us to
translate street addresses directly to latitudes and longitudes.
eod
	    ) {
	my ($module, $version, $info) = @$_;
	my @mv = $version ? ($module, $version) : ($module);
	eval "use @mv";
	$@ or do {push @prereq, $module, $version; next};
	print "\n", $info, "\n";
	if ($opt{n}) {
	    print "Because you have asserted -n, optional module @mv will not be installed.\n\n";
	    }
	  elsif ($opt{y}) {
	    print "Because you have asserted -y, optional module @mv will be installed.\n\n";
	    push @prereq, $module, $version;
	    }
	  else {
	    push @prereq, $module, $version
		if prompt ("Do you want to install optional module @mv?", 'n') =~ m/^y/i;
	    }
	}
    if ($^O eq 'MSWin32') {
	@exe_files = map {"bin/$_"} @exe_files;
	foreach (@exe_files) {`pl2bat $_`}
	@clean_files = @exe_files =
	    grep {-e $_} map {"$_.bat"} @exe_files;
	}
      elsif ($^O eq 'VMS') {
	foreach my $fni (map {"[.bin]$_"} @exe_files) {
	    my $fno = "$fni.com";
	    my $fhi = FileHandle->new ("<$fni") or die <<eod;
Error - Unable to open $fni
        $!
eod
	    my $fho = FileHandle->new (">$fno") or die <<eod;
Error - Unable to open $fno
        $!
eod
	    print $fho "$Config{startperl}\n";
	    while (<$fhi>) {print $fho $_}
	    }
	@clean_files = @exe_files = map {"[.bin]$_.com"} @exe_files;
	}
      else {
	@exe_files = map {"bin/$_"} @exe_files;
	}
    }

##my $vers = $] >= 5.008 ? '-5.8' : '';
my $vers = '';

WriteMakefile (
	NAME => 'Astro::Coord::ECI',
	VERSION_FROM => 'ECI.pm',
	PREREQ_PM => {
			@prereq
			},
	EXE_FILES => \@exe_files,
#	'linkext' => {LINKTYPE => ''},
	'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
	realclean => {FILES => join ' ', @clean_files},
	$] >= 5.005 ? (
		AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
		ABSTRACT => 'Compute satellite locations',
		BINARY_LOCATION => "$Config{archname}$vers/Astro-Coord-ECI.tar.gz",
		) : (),
	);

sub check_module {
my ($module, $version, $info) = @_;
my @mv = $version ? ($module, $version) : ($module);
eval "use @mv";
return ($module, $version) unless $@;
print $info, "\n";
if ($opt{n}) {
    print "Because you have asserted -n, optional module @mv will not be installed.\n\n";
    return ();
    }
  elsif ($opt{y}) {
    print "Because you have asserted -y, optional module @mv will be installed.\n\n";
    return ($module, $version);
    }
  else {
    }
}

