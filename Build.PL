use 5.006002;

use strict;
use warnings;

use lib qw{ inc };

use Astro::Coord::ECI::Build;
use Astro::Coord::ECI::Meta;
use Astro::Coord::ECI::Recommend;
use Module::Build;
use Config;
use FileHandle;

(my $mbv = Module::Build->VERSION) =~ s/_//g;

my $meta = Astro::Coord::ECI::Meta->new();

my %attr = (
    dist_author => 'Tom Wyant (wyant at cpan dot org)',
    dist_abstract => 'Classes and app to compute satellite visibility',
    module_name => 'Astro::Coord::ECI',
    dist_name => 'Astro-satpass',
    dist_version_from => 'lib/Astro/Coord/ECI.pm',
    requires => $meta->requires(
	perl => $meta->requires_perl(),
    ),
    build_requires => {
	'Test::More' => 0.40,
    },
    get_options => {y => {}, n => {}},
    dynamic_config => 1,
    license => 'perl',
    add_to_cleanup => [ qw{ xt/author/generated } ],
);

$mbv >= 0.28 and $attr{meta_merge} = {
    no_index => {
	directory => [qw{ inc t xt }],
    },
    resources => {
	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Astro-satpass',
	license => 'http://dev.perl.org/licenses/',
    },
};

# Don't require Module::Build if we are making a distribution, since the
# user may choose to use ExtUtils::MakeMaker.
$mbv >= 0.34
    and $attr{auto_configure_requires} = !$meta->distribution();

Astro::Coord::ECI::Recommend->recommend();

my $bldr = Astro::Coord::ECI::Build->new (%attr);

my %opt = $bldr->args ();

my @exe_files;
my @clean_files;

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

if (@exe_files) {
    if ($^O eq 'MSWin32') {
	@exe_files = map {"bin/$_"} @exe_files;
	foreach (@exe_files) {`pl2bat $_`}
	@clean_files = @exe_files =
	    grep {-e $_} map {"$_.bat"} @exe_files;
    } elsif ($^O eq 'VMS') {
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
    } else {
	@exe_files = map {"bin/$_"} @exe_files;
    }
}

$bldr->add_to_cleanup (@clean_files);
$bldr->script_files (\@exe_files);

$bldr->create_build_script ();

# ex: set textwidth=72 :
