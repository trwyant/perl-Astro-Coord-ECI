#!/usr/bin/perl

use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker qw{WriteMakefile prompt};
use FileHandle;
use Getopt::Std;

our $VERSION = '0.004_01';

my %opt;
getopts ('ny', \%opt) or die <<eod;
The only legal options are
  -n = answer all questions 'no'.
  -y = answer all questions 'yes'.
You may not assert both of these at once - it is too confusing.
eod

my @exe_files;
my @clean_files;
my @prereq = (
    );

eval {
    require t::Ctags;		# Make 'make' generate tags file.
    push @clean_files, 'tags';	# Clean it up.
};

print <<eod;

The following executable can be installed:

  satpass is a scriptable program to predict satellite passes
    over a given observer.

If you do not want this, run Makefile.PL with the -n option.

Unless you are running MSWin32 or VMS (which are special-cased),
I will assume you are running some version of U*ix, and behave
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
##	    if prompt ("Do you want to install $_?", 'n') =~ m/^y/i
	    ;
	}
    }

=for comment keep parentheses-matching editor (that does not understand POD) happy: [

=cut

my $stringmod = $] >= 5.008 ? '' : 'IO::String';

if (@exe_files) {
    push @prereq, 'Date::Manip' => 1.14;
    foreach (['Astro::SIMBAD::Query' => 0, <<eod],
Optional module Astro::SIMBAD::Query is needed if you wish to retrieve
star positions directly from the SIMBAD catalog via the 'sky lookup'
command. This functionality is experimental, and is expected to break
when SIMBAD goes to version 4.
eod
	    ['Astro::SpaceTrack' => 0.016, <<eod],
Optional module Astro::SpaceTrack version 0.016 or higher is needed if
you wish to retrieve orbital elements directly from Space Track or
Celestrak into the executable.
eod
	    [$stringmod => 0, <<eod],
Optional module $stringmod is needed if you wish to pass commands to
the executable on its command line or to write macros under a version
of Perl earlier than 5.8.
eod
	    ['SOAP::Lite' => 0, <<eod],
Optional module SOAP::Lite is needed if you wish to use Geocoder.us to
translate street addresses directly to latitudes and longitudes.
eod
	    ['XML::Parser' => 0, <<eod],
Optional module XML::Parser is needed if you wish to use
gisdata.usgs.gov to find the height above sea level at a given latitude
and longitude.
eod
	    ) {
	my ($module, $version, $info) = @$_;
	next unless $module;
	my @mv = $version ? ($module, $version) : ($module);
	eval "use @mv";
##	$@ or do {push @prereq, $module, $version; next};
	$@ or next;
	print "\n", $info, "\n";
##	if ($opt{n}) {
##	    print "Because you have asserted -n, optional module @mv will not be installed.\n\n";
##	    }
##	  elsif ($opt{y}) {
##	    print "Because you have asserted -y, optional module @mv will be installed.\n\n";
##	    push @prereq, $module, $version;
##	    }
##	  else {
##	    push @prereq, $module, $version
##		if prompt ("Do you want to install optional module @mv?", 'n')
##			=~ m/^y/i;
##	    }
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
	DISTNAME => 'Astro-satpass',
	VERSION_FROM => 'ECI.pm',
	PREREQ_PM => {
			@prereq
			},
	PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
	EXE_FILES => \@exe_files,
#	'linkext' => {LINKTYPE => ''},
	'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
	realclean => {FILES => join ' ', @clean_files},
	$] >= 5.005 ? (
		AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
		ABSTRACT => 'Classes and app to compute satellite visibility',
		BINARY_LOCATION => "$Config{archname}$vers/Astro-satpass.tar.gz",
		) : (),
	);

