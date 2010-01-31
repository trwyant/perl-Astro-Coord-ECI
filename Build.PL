use 5.006;

use strict;
use warnings;

use lib qw{ inc };

use Astro::Coord::ECI::Build;
use Astro::Coord::ECI::Recommend;
use Module::Build;
use Config;
use FileHandle;

(my $mbv = Module::Build->VERSION) =~ s/_//g;

my %attr = (
    dist_author => 'Tom Wyant (wyant at cpan dot org)',
    dist_abstract => 'Classes and app to compute satellite visibility',
    module_name => 'Astro::Coord::ECI',
    dist_name => 'Astro-satpass',
    dist_version_from => 'lib/Astro/Coord/ECI.pm',

    get_options => {y => {}, n => {}},
    dynamic_config => 1,
    license => 'perl',
    add_to_cleanup => [ qw{ xt/generated } ],
);

$mbv >= 0.28 and $attr{meta_merge} = {
    no_index => {
	directory => [qw{inc t}],
    },
    resources => {
	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-satpass',
    },
};

$mbv >= 0.34
    and $attr{auto_configure_requires} = 0;	# Don't require Module::Build

Astro::Coord::ECI::Recommend->recommend();

my $bldr = Astro::Coord::ECI::Build->new (%attr);

my %opt = $bldr->args ();

my @exe_files;
my @clean_files;
my @prereq = (
    'Params::Util'	=> 0.25,
    perl		=> 5.006,
);

print <<eod;

The following executable can be installed:

  satpass is a scriptable program to predict satellite passes
    over a given observer.

If you do not want this, run Build.PL with the -n option. If you want to
install without being asked, run Build.PL with the -y option.

Unless you are running MSWin32 or VMS (which are special-cased), I will
assume you are running some version of U*ix, and behave accordingly.

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
	    if $bldr->prompt ("Do you want to install $_?", 'n') =~ m/^y/i
	    ;
	}
    }

my $stringmod = $] >= 5.008 ? '' : 'IO::String';

if (@exe_files) {
#   push @prereq, 'Date::Manip' => 1.14;
    foreach (['Astro::SIMBAD::Client' => 0, <<eod],
Optional module Astro::SIMBAD::Client is needed if you wish to retrieve
star positions directly from the SIMBAD catalog via the 'sky lookup'
command.
eod
	    ['Astro::SpaceTrack' => 0.016, <<eod],
Optional module Astro::SpaceTrack version 0.016 or higher is needed if
you wish to retrieve orbital elements directly from Space Track or
Celestrak into the executable.
eod
	    ['Geo::WebService::Elevation::USGS' => 0, <<eod],
Optional module Geo::WebService::Elevation::USGS is needed if you
wish to retrieve the elevations of ground positions from the USGS
web site.
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
	eval "require $module";
	($@ || !$version) or eval {$module->VERSION($version)};
	$@ or next;
	print "\n", $info, "\n";
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
$bldr->build_requires({
	'Test::More' => 0.40,
    });
$bldr->add_to_cleanup (@clean_files);
$bldr->script_files (\@exe_files);

$bldr->create_build_script ();

