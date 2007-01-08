#!/usr/bin/perl

use strict;
use warnings;

use Module::Build;
use Config;
use FileHandle;

our $VERSION = '0.003_01';

my $bldr = Module::Build->new (
	dist_author => 'Tom Wyant (wyant at cpan dot org)',
	dist_abstract => 'Classes and app to compute satellite visibility',
	module_name => 'Astro::Coord::ECI',
	dist_name => 'Astro-satpass',
	dist_version_from => 'ECI.pm',

	get_options => {y => {}, n => {}},
	pm_files => {
	    'ECI.pm' => 'lib/Astro/Coord/ECI.pm',
	    'ECI/Moon.pm' => 'lib/Astro/Coord/ECI/Moon.pm',
	    'ECI/Star.pm' => 'lib/Astro/Coord/ECI/Star.pm',
	    'ECI/Sun.pm' => 'lib/Astro/Coord/ECI/Sun.pm',
	    'ECI/TLE.pm' => 'lib/Astro/Coord/ECI/TLE.pm',
	    'ECI/TLE/Set.pm' => 'lib/Astro/Coord/ECI/TLE/Set.pm',
	    'ECI/TLE/Iridium.pm' => '/lib/Astro/Coord/ECI/TLE/Iridium.pm',
	    'ECI/Utils.pm' => 'lib/Astro/Coord/ECI/Utils.pm',
	    },
	dynamic_config => 1,
	license => 'perl',
	);

my %opt = $bldr->args ();

my @exe_files;
my @clean_files;
my @prereq;

print <<eod;

The following executable can be installed:

  satpass is a scriptable program to predict satellite passes
    over a given observer.

If you do not want this, run Build.PL with the -n option.

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

$bldr->requires ({@prereq});
$bldr->add_to_cleanup (@clean_files);
$bldr->script_files (\@exe_files);

$bldr->create_build_script ();

