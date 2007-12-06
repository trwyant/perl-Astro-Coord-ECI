=head1 NAME

Astro::Coord::ECI::TLE - Compute satellite locations using NORAD orbit
propagation models

=head1 SYNOPSIS

 my @sats = Astro::Coord::ECI::TLE->parse ($tle_data);
 my $now = time ();
 foreach my $tle (@sats) {
     my @latlon = $tle->universal ($now)->geodetic ();
     my @xyz = $tle->eci ();	# For same time.
     print $tle->get ('id'), "\t@latlon\t@xyx\n";
     }

The acquisition of the orbital elements represented by $tle_data
in the above example is left as an exercise for the student.

Hint: see F<http://www.space-track.org/>, F<http://celestrak.com/>,
or L<Astro::SpaceTrack>.

=head1 DESCRIPTION

This module implements the NORAD orbital propagation models described
in their "SPACETRACK REPORT NO. 3, Models for Propagation of NORAD
Element Sets." In other words, it turns the two- or three-line
element sets available from such places as L<http://www.space-track.org/>
or L<http://celestrak.com/> into predictions of where the relevant
orbiting bodies will be. Additionally, the pass() method implements an
actual visibility prediction system.

The models implemented are:

  SGP - fairly simple, only useful for near-earth bodies;
  SGP4 - more complex, only useful for near-earth bodies;
  SDP4 - corresponds to SGP4, but for deep-space bodies;
  SGP8 - more complex still, only for near-earth bodies;
  SDP8 - corresponds to SGP8, but for deep-space bodies.

There are also some meta-models, with the smarts to run either a
near-earth model or the corresponding deep-space model depending on the
body the object represents:

  model - uses the preferred model (sgp4 or sdp4);
  model4 - runs sgp4 or sdp4;
  model8 = runs sgp8 or sdp8.

In addition, I have on at least one occasion wanted to turn off the
automatic calculation of position when the time was set. That is
accomplished with this model:

  null - does nothing.

The models do not return the coordinates directly, they simply set the
coordinates represented by the object (by virtue of being a subclass of
Astro::Coord::ECI) and return the object itself. You can then call the
appropriate inherited method to get the coordinates of the body in
whatever coordinate system is convenient. For example, to find the
latitude, longitude, and altitude of a body at a given time, you do

  my ($lat, $long, $alt) = $body->model ($time)->geodetic;

Or, assuming the L<model|/item_model> attribute is set the way you want
it, by

  my ($lat, $long, $alt) = $body->geodetic ($time);

It is also possible to run the desired model (as specified by the
L<model|/item_model> attribute) simply by setting the time represented
by the object.

At the moment, the recommended model to use is either SGP4 or SDP4,
depending on whether the orbital elements are for a near-earth or
deep-space body. For the purpose of these models, any body with a period
of at least 225 minutes is considered to be a deep-space body.

The NORAD report claims accuracy of 5 or 6 places a day after the epoch
of an element set for the original FORTRAN IV, which used (mostly) 8
place single-precision calculations. Perl typically uses many more
places, but it does not follow that the models are correspondingly more
accurate when implemented in Perl. My understanding is that in general
(i.e. disregarding the characteristics of a particular implementation of
the models involved) the total error of the predictions (including error
in measuring the position of the satellite) runs from a few hundred
meters to as much as a kilometer.

This module is a computer-assisted translation of the FORTRAN reference
implementation in "SPACETRACK REPORT NO. 3." That means, basically,
that I ran the FORTRAN through a Perl script that handled the
translation of the assignment statements into Perl, and then fixed up
the logic by hand. Dominik Borkowski's SGP C-lib was used as a reference
implementation for testing purposes, because I didn't have a Pascal
compiler, and I have yet to get any model but SGP to run correctly under
g77.

=head2 Methods

The following methods should be considered public:

=over 4

=cut

package Astro::Coord::ECI::TLE;

use strict;
use warnings;

our $VERSION = '0.010_02';

use base qw{Astro::Coord::ECI Exporter};

use Astro::Coord::ECI::Utils qw{deg2rad dynamical_delta find_first_true
    load_module mod2pi PI PIOVER2 SECSPERDAY TWOPI thetag};

use Carp qw{carp croak confess};
use Data::Dumper;
use POSIX qw{floor strftime};
use Time::Local;

{	# Local symbol block.
    my @const = qw{
	PASS_EVENT_NONE
	PASS_EVENT_SHADOWED
	PASS_EVENT_LIT
	PASS_EVENT_DAY
	PASS_EVENT_RISE
	PASS_EVENT_MAX
	PASS_EVENT_SET
	PASS_EVENT_APPULSE
    };
    our @EXPORT_OK = @const;
    our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
	constants => \@const
    );
}



# The following constants are from section 12 (Users Guide, Constants,
# and Symbols) of SpaceTrack Report No. 3, Models for Propagation of
# NORAD Element Sets by Felix R. Hoots and Ronald L. Roehrich, December
# 1980, compiled by T. S. Kelso 31 December 1988. The FORTRAN variables
# in the original are defined without the "SGP_" prefix. Were there
# are duplicates (with one commented out), the commented-out version is
# the one in the NORAD report, and the replacement has greater
# precision. If there are two commented out, the second was a greater
# precision constant, and the third is (ultimately) calculated based
# on pi = atan2 (0, -1).

use constant SGP_CK2 => 5.413080E-4;
use constant SGP_CK4 => .62098875E-6;
use constant SGP_E6A => 1.0E-6;
use constant SGP_QOMS2T => 1.88027916E-9;
use constant SGP_S => 1.01222928;
use constant SGP_TOTHRD => .66666667;
use constant SGP_XJ3 => -.253881E-5;
use constant SGP_XKE => .743669161E-1;
use constant SGP_XKMPER => 6378.135;	# Earth radius, KM.
use constant SGP_XMNPDA => 1440.0;	# Time units per day.
use constant SGP_XSCPMN => 60;		# Seconds per time unit.
use constant SGP_AE => 1.0;		# Distance units / earth radii.
## use constant SGP_DE2RA => .174532925E-1;	# radians/degree.
## use constant SGP_DE2RA => 0.0174532925199433;	# radians/degree.
use constant SGP_DE2RA => PI / 180;		# radians/degree.
## use constant SGP_PI => 3.14159265;	# Pi.
## use constant SGP_PI => 3.14159265358979;	# Pi.
use constant SGP_PI => PI;			# Pi.
## use constant SGP_PIO2 => 1.57079633;	# Pi/2.
## use constant SGP_PIO2 => 1.5707963267949;	# Pi/2.
use constant SGP_PIO2 => PIOVER2;		# Pi/2.
## use constant SGP_TWOPI => 6.2831853;	# 2 * Pi.
## use constant SGP_TWOPI => 6.28318530717959;	# 2 * Pi.
use constant SGP_TWOPI => TWOPI;		# 2 * Pi.
## use constant SGP_X3PIO2 => 4.71238898;	# 3 * Pi / 2.
## use constant SGP_X3PIO2 => 4.71238898038469;	# 3 * Pi / 2.
use constant SGP_X3PIO2 => 3 * PIOVER2;

use constant SGP_RHO => .15696615;

# FORTRAN variable glossary, read from same source, and stated in
# terms of the output produced by the parse method.
#
# EPOCH => epoch
# XNDT20 => firstderivative
# XNDD60 => secondderivative
# BSTAR => bstardrag
# XINCL => inclination
# XNODE0 => rightascension
# E0 => eccentricity
# OMEGA0 => argumentofperigee
# XM0 => meananomaly
# XNO => meanmotion


#	List all the legitimate attributes for the purposes of the
#	get and set methods. Possible values of the hash are:
#	    undef => read-only attribute
#	    0 => no model re-initializing necessary
#	    1 => at least one model needs re-initializing
#	    code reference - the reference is called with the
#		object unmodified, with the arguments
#		being the object, the name of the attribute,
#		and the new value of the attribute. The code
#		must make the needed changes to the attribute, and
#		return 0 or 1, interpreted as above.

my %attrib = (
    backdate => 0,
    classification => 0,
    international => 0,
    epoch => sub {
	$_[0]{$_[1]} = $_[2];
	$_[0]{ds50} = $_[0]->ds50 ();
	$_[0]{epoch_dynamical} = $_[2] + dynamical_delta ($_[2]);
	1},
    firstderivative => 1,
    secondderivative => 1,
    bstardrag => 1,
    ephemeristype => 0,
    elementnumber => 0,
    inclination => 1,
    model => sub {
	$_[0]->is_valid_model ($_[2]) || croak <<eod;
Error - Illegal model name '$_[2]'.
eod
	$_[0]{$_[1]} = $_[2];
	0},
    rightascension => 1,
    eccentricity => 1,
    argumentofperigee => 1,
    meananomaly => 1,
    meanmotion => 1,
    revolutionsatepoch => 0,
    debug => 0,
    geometric => 0,	# Use geometric horizon for pass rise/set.
    limb => 0,		# Whether lit when upper limb above horizon.
    visible => 0,	# Pass() reports only illuminated passes.
    appulse => 0,	# Maximum appulse to report.
    interval => 0,	# Interval for pass() positions, if positive.
    ds50 => undef,	# Read-only
    epoch_dynamical => undef,	# Read-only
    tle => undef,	# Read-only
    illum => \&_set_illum,
    reblessable => sub {
	my $doit = !$_[0]{$_[1]} && $_[2] && $_[0]->get ('id');
	$_[0]{$_[1]} = $_[2];
	$doit and $_[0]->rebless ();
	0},
    );
my %static = (
    appulse => deg2rad (10),	# Report appulses < 10 degrees.
    backdate => 1,	# Use object in pass before its epoch.
    geometric => 0,	# Use geometric horizon for pass rise/set.
    illum => 'sun',
    interval => 0,
    limb => 1,
    model => 'model',
    reblessable => 1,
    visible => 1,
);
my %model_attrib = (	# For the benefit of is_model_attribute()
    ds50 => 1,		# Read-only, but it fits the definition.
    epoch => 1,		# Hand-set, since we dont want to call the code.
    epoch_dynamical => 1,	# Read-only, but fits the definition.
    );
foreach (keys %attrib) {
    $model_attrib{$_} = 1 if $attrib{$_} && !ref $attrib{$_}
    }
my %status;	# Subclassing data - initialized at end

use constant TLE_INIT => '_init';

=item $tle = Astro::Coord::ECI::TLE->new()

This method instantiates an object to represent a NORAD two- or
three-line orbital element set. This is a subclass of
B<Astro::Coord::ECI>.

Any arguments get passed to the set() method.

It is both anticipated and recommended that you use the parse()
method instead of this method to create an object, since the models
currently have no code to guard against incomplete data.

=cut

sub new {
my $class = shift;
my $self = $class->SUPER::new (%static, @_);
$self;
}

=item $tle->after_reblessing (\%possible_attributes)

This method supports reblessing into a subclass, with the argument
representing attributes that the subclass may wish to set.  It is called
by rebless() and should not be called by the user.

At this level it does nothing.

=cut

sub after_reblessing {}

=item Astro::Coord::ECI::TLE->alias (name => class ...)

This static method adds an alias for a class name, for the benefit of
users of the status() method and 'illum' attributes, and ultimately of
the rebless() method. It is intended to be used by subclasses to
register short names for themselves upon initialization, though of
course you can call it yourself as well.

For example, this class calls

 __PACKAGE__->alias (tle => __PACKAGE__);

You can register more than one alias in a single call. Aliases
can be deleted by assigning them a false value (e.g. '' or undef).

If called without arguments, it returns the current aliases.

You can actually call this as a normal method, but it still behaves
like a static method.

=cut

my %type_map = ();

sub alias {
    my $self = shift;
    @_ % 2 and croak <<eod;
Error - Must have even number of arguments for alias().
eod
    return wantarray ? %type_map : {%type_map} unless @_;
    while (@_) {
	my $name = shift;
	my $class = shift or do {
	    delete $type_map{$name};
	    next;
	};
	$class = $type_map{$class} if $type_map{$class};
	load_module ($class);
	$type_map{$name} = $class;
    }
}
__PACKAGE__->alias (tle => __PACKAGE__);


#	See Astro::Coord::ECI for docs.

sub attribute {
$attrib{$_[1]} ? __PACKAGE__ : $_[0]->SUPER::attribute ($_[1])
}


=item $tle->before_reblessing ()

This method supports reblessing into a subclass. It is intended to do
any cleanup the old class needs before reblessing into the new class. It
is called by rebless(), and should not be called by the user.

At this level it does nothing.

=cut

sub before_reblessing {}


=item $tle->can_flare ()

This method returns true if the object is capable of generating flares
(i.e. predictable bright flashes) and false otherwise. At this level
of the inheritance hierarchy, it always returns false, but subclasses
may return true.

=cut

sub can_flare {0}


=item $value = $tle->ds50($time)

This method converts the time to days since 1950 Jan 0, 0 h GMT.
The time defaults to the epoch of the data set. This method does not
affect the $tle object - it is exposed for convenience and for testing
purposes.

It can also be called as a "static" method, i.e. as
Astro::Coord::ECI::TLE->ds50 ($time), but in this case the time may not
be defaulted, and no attempt has been made to make this a pretty error.

=cut

{	# Begin local symbol block

#	Because different Perl implementations may have different
#	epochs, we assume that 2000 Jan 1 0h UT is representable, and
#	pre-calculate that time in terms of seconds since the epoch.
#	Then, when the method is called, we convert the argument to
#	days since Y2K, and then add the magic number needed to get
#	us to days since 1950 Jan 0 0h UT.

my $y2k = timegm (0, 0, 0, 1, 0, 100);	# Calc. time of 2000 Jan 1 0h UT

sub ds50 {
my $self = shift;
my $epoch = @_ ? $_[0] : $self->{epoch};
my $rslt = ($epoch - $y2k) / 86400 + 18263;
ref $self && $self->{debug} and print <<eod;
Debug ds50 ($epoch) = $rslt
eod
$rslt;
}
}	# End local symbol block


=item $value = $tle->get('attribute')

This method retrieves the value of the given attribute. See the
L</Attributes> section for a description of the attributes.

=cut

sub get {
my $self = shift;
my $name = shift;
if (ref $self) {
    exists $attrib{$name} or return $self->SUPER::get ($name);
    return $self->{$name};
    }
  else {
    exists $static{$name} or
	return $self->SUPER::get ($name);
    return $static{$name};
    }
}


=item $deep = $tle->is_deep();

This method returns true if the object is in deep space - meaning that
its period is at least 225 minutes (= 13500 seconds).

=cut

sub is_deep {
return $_[0]->{&TLE_INIT}{TLE_isdeep} if exists $_[0]->{&TLE_INIT}{TLE_isdeep};
return ($_[0]->{&TLE_INIT}{TLE_isdeep} = $_[0]->period () >= 13500);
}

=item $boolean = $tle->is_model_attribute ($name);

This method returns true if the named attribute is an attribute of
the model - i.e. it came from the TLE data and actually affects the
model computations. It is really for the benefit of
Astro::Coord::ECI::TLE::Set, so that class can determine how its
set() method should handle the attribute.

=cut

sub is_model_attribute { $model_attrib{$_[1]} }

=item $boolean = $tle->is_valid_model ($model_name);

This method returns true if the given name is the name of an orbital
model, and false otherwise.

Actually, in the spirit of UNIVERSAL::can, it returns a reference to
the code if the model exists, and undef otherwise.

This is really for the benefit of Astro::Coord::ECI::TLE::Set, so it
can select the correct member object before running the model.

=cut

{	# Begin local symbol block

my %valid = map {$_ => UNIVERSAL::can (__PACKAGE__, $_)}
    qw{model model4 model8 null sdp4 sdp8 sgp sgp4 sgp8};

    sub is_valid_model {
    $valid{$_[1]}
    }

}	# End local symbol block


=item $tle = $tle->model($time)

This method calculates the position of the body described by the TLE
object at the given time, using the preferred model. Currently this is
SGP4 for near-earth objects, or SDP4 for deep-space objects.

The intent is that this method will use whatever model is currently
preferred. If the preferred model changes, this method will use the
new preferred model as soon as I:

  - Find out about the change;
  - Can get the specifications for the new model;
  - Can find the time to code up the new model.

You need to call one of the Astro::Coord::ECI methods (e.g. geodetic ()
or equatorial ()) to retrieve the position you just calculated.

=cut

sub model {
return $_[0]->is_deep ? $_[0]->sdp4 ($_[1]) : $_[0]->sgp4 ($_[1]);
}

=item $tle = $tle->model4 ($time)

This method calculates the position of the body described by the TLE
object at the given time, using either the SGP4 or SDP4 model,
whichever is appropriate. If the preferred model becomes S*P8,
this method will still use S*P4.


You need to call one of the Astro::Coord::ECI methods (e.g. geodetic ()
or equatorial ()) to retrieve the position you just calculated.

=cut

sub model4 {
return $_[0]->is_deep ? $_[0]->sdp4 ($_[1]) : $_[0]->sgp4 ($_[1]);
}

=item $tle = $tle->model8 ($time)

This method calculates the position of the body described by the TLE
object at the given time, using either the SGP8 or SDP8 model,
whichever is appropriate.

You need to call one of the Astro::Coord::ECI methods (e.g. geodetic ()
or equatorial ()) to retrieve the position you just calculated.

=cut

sub model8 {
return $_[0]->is_deep ? $_[0]->sdp8 ($_[1]) : $_[0]->sgp8 ($_[1]);
}

=item $tle = $tle->null ($time)

This method does nothing. It is a valid orbital model, though. If you
call $tle->set (model => 'null'), no position calculation is done as a
side effect of calling $tle->universal ($time).

=cut

sub null {}


=item @elements = Astro::Coord::ECI::TLE->parse (@data);

This method parses a NORAD two- or three-line element set (or a
mixture), returning a list of Astro::Coord::ECI::TLE objects. The
L</Attributes> section identifies those attributes which will be filled
in by this method.

The input will be split into individual lines, and all blank lines and
lines beginning with '#' will be eliminated. The remaining lines are
assumed to represent two- or three-line element sets, in so-called
external format. Internal format (denoted by a 'G' in column 79 of line
1 of the set, not counting the common name if any) is not supported,
and the presence of such data will result in an exception being thrown.

=cut

sub parse {
my $self = shift;
my @rslt;
###!!! my $subclass = ref $_[0] eq 'HASH' ? shift : {};
my @data = grep {$_ && $_ !~ m/^\s*#/} map {chomp; $_}
    map {ref $_ && croak <<eod; split '\n', $_} @_;
Error - The hash reference must be the first argument to parse ().
eod
while (@data) {
    my %ele = %static;
    my $line = shift @data;
    $line =~ s/\s+$//;
    my $tle = "$line\n";
    length ($line) < 50 and do {
	($ele{name}, $line) = ($line, shift @data);
	$line =~ s/\s+$//;
	$tle .= "$line\n";
	};
    if (length ($line) > 79 && substr ($line, 79, 1) eq 'G') {
	croak "G (internal) format data not supported";
	}
      else {
	$line =~ m/^1(\s*\d+)/ && length ($1) == 6 or
	    croak "Invalid line 1 '$line'";
	length ($line) < 80 and $line .= ' ' x (80 - length ($line));
	@ele{qw{id classification international epoch firstderivative
	    secondderivative bstardrag ephemeristype elementnumber}} =
	    unpack 'x2A5A1x1A8x1A14x1A10x1A8x1A8x1A1x1A4', $line;
	$line = shift @data;
	$tle .= "$line\n";
	$line =~ m/^2(\s*\d+)/ && length ($1) == 6 or
	    croak "Invalid line 2 '$line'";
	length ($line) < 80 and $line .= ' ' x (80 - length ($line));
	@ele{qw{id_2 inclination rightascension eccentricity argumentofperigee
	    meananomaly meanmotion revolutionsatepoch}} =
	    unpack 'x2A5x1A8x1A8x1A7x1A8x1A8x1A11A5', $line;
	$ele{id} == $ele{id_2} or
	    croak "Invalid data. Line 1 was for id $ele{id} but line 2 was for $ele{id_2}";
	delete $ele{id_2};
	}
    foreach (qw{eccentricity}) {$ele{$_} = "0.$ele{$_}" + 0}
    foreach (qw{secondderivative bstardrag}) {
	$ele{$_} =~ s/(.)(.{5})(..)/$1.$2e$3/;
	$ele{$_} += 0;
	}
    foreach (qw{epoch}) {
	my ($yr, $day) = $ele{$_} =~ m/(..)(.*)/;
	$yr += 100 if $yr < 57;
	$ele{$_} = timegm (0, 0, 0, 1, 0, $yr) + ($day - 1) * 86400;
	}

#	From here is conversion to the units expected by the
#	models.

    foreach (qw{rightascension argumentofperigee meananomaly
    		inclination}) {
	$ele{$_} *= SGP_DE2RA;
	}
    my $temp = SGP_TWOPI;
    foreach (qw{meanmotion firstderivative secondderivative}) {
	$temp /= SGP_XMNPDA;
	$ele{$_} *= $temp;
	}
    my $id  = $ele{id};
    my $body = __PACKAGE__->new (%ele);	# Note that setting the ID does the reblessing.
    $body->{tle} = $tle;
    push @rslt, $body;
    }
return @rslt;
}

# Parse information for the above from
# CelesTrak "FAQs: Two-Line Element Set Format", by Dr. T. S. Kelso,
# http://celestrak.com/columns/v04n03/
# Per this, all data are for the NORAD SGP4/SDP4 model, except for the
# first and second time derivative, which are for the simpler SGP model.
# The actual documentation of the algorithms, along with a reference
# implementation in FORTRAN, is available at
# http://celestrak.com/NORAD/documentation/spacetrk.pdf

=item @passes = $tle->pass ($station, $start, $end, \@sky)

This method returns passes of the body over the given station between
the given start end end times. The \@sky argument is background bodies
to compute appulses with.

All arguments except $station are optional, the defaults being

 $start = time()
 $end = $start + 7 days
 \@sky = []

The return is a list of passes, which may be empty. Each pass is
represented by an anonymous hash containing the following keys:

  {body} => Reference to body making pass;
  {time} => Time of pass (culmination);
  {events} => [the individual events of the pass].

The individual events are also anonymous hashes, with each hash
containing the following keys:

  {azimuth} => Azimuth of event in radians;
  {body} => Reference to body making pass;
  {appulse} => {  # This is present only for PASS_EVENT_APPULSE;
      {angle} => minimum separation in radians;
      {body} => other body involved in appulse;
      }
  {elevation} => Elevation of event in radians;
  {event} => Event code (PASS_EVENT_xxxx);
  {illumination} => Illumination at time of event (PASS_EVENT_xxxx);
  {range} => Distance to event in kilometers;
  {station} => Reference to observing station;
  {time} => Time of event;

Note that the time set in the various {body} and {station} objects is
B<not> guaranteed to be anything in particular. Specifically, it is
almost certainly not the time of the event.

The events are coded by the following manifest constants:

  PASS_EVENT_NONE => dualvar (0, '');
  PASS_EVENT_SHADOWED => dualvar (1, 'shdw');
  PASS_EVENT_LIT => dualvar (2, 'lit');
  PASS_EVENT_DAY => dualvar (3, 'day');
  PASS_EVENT_RISE => dualvar (4, 'rise');
  PASS_EVENT_MAX => dualvar (5, 'max');
  PASS_EVENT_SET => dualvar (6, 'set');
  PASS_EVENT_APPULSE => dualvar (7, 'apls');

The dualvar function comes from Scalar::Util, and generates values
which are numeric in numeric context and strings in string context. If
Scalar::Util cannot be loaded the numeric values are returned.

These manifest constants can be imported using the individual names, or
the tags ':constant' or ':all'. They can also be accessed as methods
using (e.g.) $tle->PASS_EVENT_LIT, or as static methods using (e.g.)
Astro::Coord::ECI::TLE->PASS_EVENT_LIT.

Illumination is represented by one of PASS_EVENT_SHADOWED,
PASS_EVENT_LIT, or PASS_EVENT_DAY. The first two are calculated based on
whether the illuminating body (i.e. the body specified by the 'illum'
attribute) is above the horizon; the third is based on whether the Sun
is higher than specified by the 'twilight' attribute, and trumps the
other two (i.e. if it's day it doesn't matter whether the satellite is
illuminated).

Time resolution of the events is typically to the nearest second, except
for appulses, which need to be calculated more closely to detect
transits. The time reported for the event is the time B<after> the event
occurred. For example, the time reported for rise is the earliest time
the body is found above the horizon, and the time reported for set is
the earliest time the body is found below the horizon.

The operation of this method is affected by the following attributes,
in addition to its arguments and the orbital elements associated with
the object:

  * appulse	# Maximum appulse to report
  * geometric	# Use geometric horizon for pass rise/set
  * horizon	# Effective horizon
  * interval	# Interval for pass() positions, if positive
  * illum	# Source of illumination.
  * limb	# Whether lit when upper limb above horizon
  * twilight	# Distance of illuminator below horizon
  * visible	# Pass() reports only illuminated passes

=cut

BEGIN {
    eval {use Scalar::Util qw{dualvar}};
    $@ and *dualvar = sub {$_[0]};
}

use constant PASS_EVENT_NONE => dualvar (0, '');	# Guaranteed false.
use constant PASS_EVENT_SHADOWED => dualvar (1, 'shdw');
use constant PASS_EVENT_LIT => dualvar (2, 'lit');
use constant PASS_EVENT_DAY => dualvar (3, 'day');
use constant PASS_EVENT_RISE => dualvar (4, 'rise');
use constant PASS_EVENT_MAX => dualvar (5, 'max');
use constant PASS_EVENT_SET => dualvar (6, 'set');
use constant PASS_EVENT_APPULSE => dualvar (7, 'apls');

# *****	Promise Astro::Coord::ECI::TLE::Set that pass() only uses the
# *****	public interface. That way pass() will get the Set object,
# *****	and will work if we have more than one set of elements for the
# *****	body, even if we switch element sets in the middle of a pass.

*_nodelegate_pass = \&pass;

sub pass {

    my @sky = @{pop @_} if ref $_[$#_] eq 'ARRAY';
    my $tle = shift;
    my $sta = shift;
    my $pass_start = shift || time ();
    my $pass_end = shift || $pass_start + 7 * SECSPERDAY;
    $pass_end >= $pass_start or croak <<eod;
Error - End time must be after start time.
eod
    unless ($tle->get ('backdate')) {
	my $real = $tle->isa ('Astro::Coord::ECI::TLE::Set') ?
	    $tle->select ($pass_start) : $tle;
	my $epoch = $real->get ('epoch');
	$pass_start = $epoch if $pass_start < $epoch;
	$pass_start <= $pass_end or return ();
    }

    my @lighting = (
	PASS_EVENT_SHADOWED,
	PASS_EVENT_LIT,
	PASS_EVENT_DAY,
    );
    my $verbose = $tle->get ('interval');
    my $pass_step = $verbose || 60;
    my $horizon = $tle->get ('horizon');
    my $effective_horizon = $tle->get ('geometric') ? 0 : $horizon;
    my $twilight = $tle->get ('twilight');
    my $want_lit = $tle->get ('limb');
    my $want_visible = $tle->get ('visible');
    my $want_exact = 1;			# Always want exact event timings.
    my $appulse_dist = $tle->get ('appulse');
    my $debug = $tle->get ('debug');

#	We need the sun at some point.

    my $sun = Astro::Coord::ECI::Sun->new ();
    my $illum = $tle->get ('illum');

#	Foreach body to be modelled

    my $id = $tle->get ('id');
    my $name = $tle->get ('name');
    $name = $name ? " - $name" : '';

    my $bm_start = time ();


#	For each time to be covered

    my $step = $pass_step;
    my $bigstep = 5 * $step;
    my $littlestep = $step;
    my $end = $pass_end;
    my $day = '';
    my ($suntim, $rise) =
	$sta->universal ($pass_start)->next_elevation ($sun, $twilight);
    my @info;	# Information on an individual pass.
    my @passes;	# Accumulated informtion on all passes.
    my $visible;
    my $culmination;	# Time of maximum elevation.
    for (my $time = $pass_start; $time <= $end; $time += $step) {


#	If the current sun event has occurred, handle it and calculate
#	the next one.

	if ($time >= $suntim) {
	    ($suntim, $rise) =
		$sta->universal ($suntim)->next_elevation ($sun, $twilight);
	    }


#	Skip if the sun is up.

	next if $want_visible && !@info && !$rise && $time < $suntim;


#	Calculate azimuth and elevation.

	my ($azm, $elev, $rng) = $sta->azel ($tle->universal ($time));


#	Adjust the step size based on how far the body is below the
#	horizon.

	$step = $elev < -.4 ? $bigstep : $littlestep;


#	If the body is below the horizon, we check for accumulated data,
#	handle it if any, clear it, and on to the next iteration.

	if ($elev < $effective_horizon) {
	    @info = () unless $visible;
	    next unless @info;


#	    We may have skipped part of the pass because it began in
#	    daylight. Pick up that part now.

	    while ($want_visible) {
		my $time = $info[0]{time} - $step;
		last if $elev < $effective_horizon;
		my ($lat, $long, $alt) = $tle->geodetic;
		my $litup = $time < $suntim ? 2 - $rise : 1 + $rise;
		$litup = 0 if $litup == 1 &&
		    ($tle->azel ($illum->universal ($time), $want_lit))[1]
		    < $tle->dip ();
		unshift @info, {
		    azimuth => $azm,
		    elevation => $elev,
		    event => PASS_EVENT_NONE,
		    illumination => $lighting[$litup],
		    range => $rng,
		    time => $time,
		    };
		}


#	    If we want the exact times of the events, compute them.

	    if ($want_exact) {


#		Compute exact rise, max, and set.

		my @time = (
		    [find_first_true ($info[0]{time} - $step, $info[0]{time},
			sub {($sta->azel ($tle->universal ($_[0])))[1] >=
			$effective_horizon}), PASS_EVENT_RISE],
		    [find_first_true ($info[$#info]{time}, $info[$#info]{time}
			    + $step,
			sub {($sta->azel ($tle->universal ($_[0])))[1] <
			$effective_horizon}), PASS_EVENT_SET],
		    [find_first_true ($info[0]{time}, $info[$#info]{time},
			sub {($sta->azel ($tle->universal ($_[0])))[1] >
				($sta->azel ($tle->universal ($_[0] + 1)))[1]}),
				PASS_EVENT_MAX],
		    );
		$culmination = $time[2][0];
		warn <<eod if $debug;

Debug - Computed @{[strftime '%d-%b-%Y %H:%M:%S', localtime $time[0][0]
		    ]} $time[0][1]
                 @{[strftime '%d-%b-%Y %H:%M:%S', localtime $time[1][0]
		    ]} $time[1][1]
                 @{[strftime '%d-%b-%Y %H:%M:%S', localtime $time[2][0]
		    ]} $time[2][1]
eod

#		Compute visibility changes.

		my $last;
		foreach my $evt (@info) {
		    $last or next;
		    $evt->{illumination} == $last->{illumination} and next;
		    my ($suntim, $rise) =
			$sta->universal ($last->{time})->
			next_elevation ($sun, $twilight);
		    push @time, [find_first_true ($last->{time}, $evt->{time},
			sub {
			    my $litup = $_[0] < $suntim ?
				2 - $rise : 1 + $rise;
			    $litup = 0 if $litup == 1 &&
				($tle->azel ($illum->universal ($_[0]),
					$want_lit))[1] < $tle->dip ();
			    $lighting[$litup] == $evt->{illumination}
			    }),
			    $evt->{illumination}];
			warn <<eod if $debug;
                 @{[strftime '%d-%b-%Y %H:%M:%S', localtime $time[$#time][0]]} $evt->{illumination}
                 @{[strftime '%d-%b-%Y %H:%M:%S', localtime $time[2][0]]} $time[2][1]
eod
		    }
		  continue {
		    $last = $evt;
		    }


#		Compute nearest approach to background bodies

#		Note (fortuitous discovery) the ISS travels 1.175
#		degrees per second at the zenith, so I need better
#		than 1 second resolution to detect a transit.

		foreach my $body (@sky) {
		    my $when = find_first_true ($time[0][0], $time[1][0],
			sub {$sta->angle ($body->universal ($_[0]),
					$tle->universal ($_[0])) <
				$sta->angle ($body->universal ($_[0] + .1),
					$tle->universal ($_[0] + .1))},
			.1);
		    my $angle = 
			$sta->angle ($body->universal ($when),
				$tle->universal ($when));
		    next if $angle > $appulse_dist;
		    push @time, [$when, PASS_EVENT_APPULSE,
			appulse => {angle => $angle, body => $body}];
		    warn <<eod if $debug;
                $time[$#time][1] @{[strftime '%d-%b-%Y %H:%M:%S', localtime $time[$#time][0]]}
eod
		    }


#		Clear the original data unless we're verbose.

		@info = () unless $verbose;


#		Generate the full data for the exact events.

		my ($suntim, $rise);
		warn "Contents of \@time: ", Dumper (\@time) if $debug;
		foreach (sort {$a->[0] <=> $b->[0]} @time) {
		    my @event = @$_;
		    my $time = shift @event;
		    ($suntim, $rise) =
			$sta->universal ($time)->next_elevation ($sun, $twilight)
			if !$suntim || $time >= $suntim;
		    my ($azm, $elev, $rng) = $sta->azel ($tle->universal ($time));
		    my $litup = $time < $suntim ? 2 - $rise : 1 + $rise;
		    $litup = 0 if $litup == 1 &&
			($tle->azel ($illum->universal ($time),
				$want_lit))[1] < $tle->dip ();
		    push @info, {
			azimuth => $azm,
			body => $tle,
			elevation => $elev,
			event => @event,
			illumination => $lighting[$litup],
			range => $rng,
			station => $sta,
			time => $time,
			};
		    }


#		Sort the data, and eliminate duplicates.

		my @foo = sort {$a->{time} <=> $b->{time}} @info;
		$last = undef;
		@info = ();
		foreach my $evt (@foo) {
		    push @info, $evt unless defined $last &&
			$evt->{time} == $last->{time} &&
			$evt->{event} != PASS_EVENT_APPULSE;
		    $last = $evt;
		    }
		}


#	    Figure out what the events are.

	    unless ($want_exact) {
		$info[0]{event} = PASS_EVENT_RISE;
		$info[$#info]{event} = PASS_EVENT_SET;
		$info[$#info]{elevation} = 0 if $info[$#info]{elevation} < 0;
					# Because -.6 degrees (which we
					# get because no atmospheric
					# refraction below the horizon)
					# looks funny.
		my ($last, $max);
		foreach my $pt (@info) {
		    $last or next;
		    $last->{elevation} > $pt->{elevation} and $max ||= $last;
		    $last->{illumination} != $pt->{illumination} and
			$pt->{event} ||= $pt->{illumination};
		    }
		continue {
		    $last = $pt;
		    }
		$max and do {
		    $max->{event} = PASS_EVENT_MAX;
		    $culmination = $max->{time};
		    };
		}


#	    Record the data for the pass.

	    confess <<eod unless defined $culmination;
Programming error - \$culmination undefined at end of pass calculation.
eod
	    push @passes, {
		body => $tle,
		events => [@info],
		time => $culmination,
		};

#	    Clear out the data.

	    @info = ();
	    $visible = 0;
	    $culmination = undef;
	    next;
	    }


#	Calculate whether the body is illuminated.

	my $litup = $time < $suntim ? 2 - $rise : 1 + $rise;
	$litup = 0 if $litup == 1 &&
	    ($tle->azel ($illum->universal ($time),
		    $want_lit))[1] < $tle->dip ();
	$visible ||= ($litup == 1 || !$want_visible) && $elev > $horizon;


#	Accumulate results.

	push @info, {
	    azimuth => $azm,
	    elevation => $elev,
	    event => PASS_EVENT_NONE,
	    illumination => $lighting[$litup],
	    range => $rng,
	    time => $time,
	    };

	}
    @passes;

}


=item $seconds = $tle->period ();

This method returns the orbital period of the object in seconds.

=for comment help parenthesis-matching editor }

=cut

sub period {
return $_[0]->{&TLE_INIT}{TLE_period} if exists $_[0]->{&TLE_INIT}{TLE_period};
my $self = shift;

my $a1 = (SGP_XKE / $self->{meanmotion}) ** SGP_TOTHRD;
my $temp = 1.5 * SGP_CK2 * (3 * cos ($self->{inclination}) ** 2 - 1) /
	(1 - $self->{eccentricity} * $self->{eccentricity}) ** 1.5;
my $del1 = $temp / ($a1 * $a1);
my $a0 = $a1 * (1 - $del1 * (.5 * SGP_TOTHRD +
	$del1 * (1 + 134/81 * $del1)));
my $del0 = $temp / ($a0 * $a0);
my $xnodp = $self->{meanmotion} / (1 + $del0);
return ($self->{_period} = SGP_TWOPI / $xnodp * SGP_XSCPMN);
}


=item $tle = $tle->rebless ($class, \%possible_attributes)

This method reblesses a TLE object. The class must be either
Astro::Coord::TLE or a subclass thereof, as must the object passed in to
be reblessed. If the $tle object has its L<reblessable|/reblessable>
attribute false, it will not be reblessed, but will be returned
unmodified. Before reblessing, the before_reblessing() method is called.
After reblessing, the after_reblessing() method is called with the
\%possible_attributes hash reference as argument.

It is possible to omit the $class argument if the \%possible_attributes
argument contains the keys {class} or {type}, taken in that order. If
the $class argument is omitted and the \%possible_attributes hash does
B<not> have the requisite keys, the $tle object is unmodified.

It is also possible to omit both arguments, in which case the object
will be reblessed according to the content of the internal status
table.

For convenience, you can pass an alias instead of the full class name. The
following aliases are recognized:

 iridium => 'Astro::Coord::ECI::TLE::Iridium'
 tle => 'Astro::Coord::ECI::TLE'

Other aliases may be defined with the alias() static method.

Note that this method returns the original object (possibly reblessed).
It does not under any circumstances manufacture another object.

=cut

sub rebless {
my $tle = shift;
UNIVERSAL::isa ($tle, __PACKAGE__) or croak <<eod;
Error - You can only rebless an object of class @{[__PACKAGE__]}
        or a subclass thereof. The object you are trying to rebless
	is of class @{[ref $tle]}.
eod
$tle->get ('reblessable') or return $tle;
@_ or do {
    my $id = $tle->get ('id') or return $tle;
    @_ = $status{$id} || 'tle';
    };
my $class = ref $_[0] eq 'HASH' ? $_[0]->{class} || $_[0]->{type} : shift
    or return $tle;
$class = $type_map{$class} if $type_map{$class};
load_module ($class);
UNIVERSAL::isa ($class, __PACKAGE__) or croak <<eod;
Error - You can only rebless an object into @{[__PACKAGE__]} or
        a subclass thereof. You are trying to rebless the object
	into $class.
eod
$tle->before_reblessing ();
bless $tle, $class;
$tle->after_reblessing (@_);
$tle;
}


=item $tle->set (attribute => value ...)

This method sets the values of the various attributes. The changing of
attributes actually used by the orbital models will cause the models to
be reinitialized. This happens transparently, and is no big deal. For
a description of the attributes, see L</Attributes>.

Because this is a subclass of Astro::Coord::ECI, any attributes of that
class can also be set.

=cut

sub set {
my $self = shift;
@_ % 2 and croak "The set method takes an even number of arguments.";
my ($clear, $extant);
if (ref $self) {
    $extant = \%attrib;
    }
  else {
    $self = $extant = \%static;
    }
while (@_) {
    my $name = shift;
    exists $extant->{$name} or do {
	$self->SUPER::set ($name, shift);
	next;
	};
    defined $attrib{$name} or croak "Attribute $name is read-only.";
    if (ref $attrib{$name} eq 'CODE') {
	$attrib{$name}->($self, $name, shift) and $clear = 1;
	}
      else {
	$self->{$name} = shift;
	$clear ||= $attrib{$name};
	}
    }
$clear and delete $self->{&TLE_INIT};
}


=item Astro::Coord::ECI::TLE->status (command => arguments ...)

This method maintains the internal status table, which is used by the
parse() method to determine which subclass (if any) to bless the
created object into. The first argument determines what is done to the
status table; subsequent arguments depend on the first argument. Valid
commands and arguments are:

status (add => $id, $type => $status, $name, $comment) adds an item to
the status table or modifies an existing item. The $id is the NORAD ID
of the body. The only currently-supported $type is
'Astro::Coord::ECI::TLE::Iridium', but any alias to this will also work
(see alias(); 'iridium' is defined by default). The $status is
0, 1, or 2, representing in-service, spare, or failed respectively. The
strings '+' or '' will be interpreted as 0, 'S', 's', or '?' as 1, and
any other non-numeric string as 2. The  $name and $comment arguments
default to empty.

status ('clear') clears the status table.

status (clear => 'type') clears all entries of the given type in the
status table. For supported types, see the discussion of 'add',
above.

status (drop => $id) removes the given NORAD ID from the status table.

status ('show') returns a list of list references, representing the
'add' commands which would be used to regenerate the status table.

=cut

use constant STATUS_IN_SERVICE => 0;
use constant STATUS_SPARE => 1;
use constant STATUS_TUMBLING => 2;

my %status_map = (
    ''	=> STATUS_IN_SERVICE,
    '+'	=> STATUS_IN_SERVICE,
    '?'	=> STATUS_SPARE,
    'S' => STATUS_SPARE,
    's' => STATUS_SPARE,
);

sub status {
shift;	# Ignore the class name.
my $cmd = shift;
if ($cmd eq 'add') {
    my $id = shift or croak <<eod;
Error - The status ('add') call requires a NORAD ID.
eod
    my $type = shift or croak <<eod;
Error - The status (add => $id) call requires a type.
eod
    my $class = $type_map{$type} || $type;
    $class->isa (__PACKAGE__) or croak <<eod;
Error - $type must specify a subclass of @{[__PACKAGE__]}.
eod
    my $status = shift || 0;
    $status =~ m/\D/
	and $status = exists $status_map{$status} ?
	   $status_map{$status} : STATUS_TUMBLING;
    my $name = shift || '';
    my $comment = shift || '';
    $status{$id} = {
	comment => $comment,
	status => $status,
	name => $name,
	id => $id,
	type => $type,
	class => $class,
	};
    }
  elsif ($cmd eq 'clear') {
    my $type = shift;
    if (!defined $type) {
	%status = ();
	}
      else {
	my $class = $type_map{$type} || $type;
	$class->isa (__PACKAGE__) or croak <<eod;
Error - $type must specify a subclass of @{[__PACKAGE__]}.
eod
	foreach my $key (keys %status) {
	    $status{$key}{class} eq $class and delete $status{$key};
	    }
	}
    }
  elsif ($cmd eq 'drop') {
    my $id = shift or croak <<eod;
Error - The status ('drop') call requires a NORAD ID.
eod
    delete $status{$id};
    }
  elsif ($cmd eq 'dump') {	# <<<< Undocumented!!!
    local $Data::Dumper::Terse = 1;
    print __PACKAGE__, " status = ", Dumper (\%status);
    }
  elsif ($cmd eq 'show') {
    sort {$a->[0] <=> $b->[0]}
        map {[$_->{id}, $_->{type}, $_->{status}, $_->{name},
	$_->{comment}]} values %status;
    }
  else {
    croak <<eod;
Error - '$cmd' is not a legal status() command.
eod
    }
}

=item $tle = $tle->sgp($time)

This method calculates the position of the body described by the TLE
object at the given time, using the SGP model. The universal time of the
object is set to $time, and the 'equinox_dynamical' attribute is set to
to the current value of the 'epoch_dynamical' attribute.

The result is the original object reference. You need to call one of
the Astro::Coord::ECI methods (e.g. geodetic () or equatorial ()) to
retrieve the position you just calculated.

"Spacetrack Report Number 3" (see "Acknowledgments") says that this
model can be used for either near-earth or deep-space orbits, but the
reference implementation they provide dies on an attempt to use this
model for a deep-space object, and I have followed the reference
implementation.

=cut

sub sgp {
my $self = shift;
my $time = shift;
my $tsince = ($time - $self->{epoch}) / 60;	# Calc. is in minutes.


#*	Initialization.

#>>>	Rather than use a separate indicator argument to trigger
#>>>	initialization of the model, we use the Orcish maneuver to
#>>>	retrieve the results of initialization, performing the
#>>>	calculations if needed. -- TRW

my $parm = $self->{&TLE_INIT}{TLE_sgp} ||= do {
    $self->is_deep and croak <<EOD;
Error - The SGP model is not valid for deep space objects.
        Use the SDP4 or SDP8 models instead.
EOD
    my $c1 = SGP_CK2 * 1.5;
    my $c2 = SGP_CK2 / 4;
    my $c3 = SGP_CK2 / 2;
    my $c4 = SGP_XJ3 * SGP_AE ** 3 / (4 * SGP_CK2);
    my $cosi0 = cos ($self->{inclination});
    my $sini0 = sin ($self->{inclination});
    my $a1 = (SGP_XKE / $self->{meanmotion}) ** SGP_TOTHRD;
    my $d1 = $c1 / $a1 / $a1 * (3 * $cosi0 * $cosi0 - 1) /
	(1 - $self->{eccentricity} * $self->{eccentricity}) ** 1.5;
    my $a0 = $a1 *
	(1 - 1/3 * $d1 - $d1 * $d1 - 134/81 * $d1 * $d1 * $d1); 
    my $p0 = $a0 * (1 - $self->{eccentricity} * $self->{eccentricity});
    my $q0 = $a0 * (1 - $self->{eccentricity});
    my $xlo = $self->{meananomaly} + $self->{argumentofperigee} +
	$self->{rightascension};
    my $d10 = $c3 * $sini0 * $sini0;
    my $d20 = $c2 * (7 * $cosi0 * $cosi0 - 1);
    my $d30 = $c1 * $cosi0;
    my $d40 = $d30 * $sini0;
    my $po2no = $self->{meanmotion} / ($p0 * $p0);
    my $omgdt = $c1 * $po2no * (5 * $cosi0 * $cosi0 - 1);
    my $xnodot = -2 * $d30 * $po2no;
    my $c5 = .5 * $c4 * $sini0 * (3 + 5 * $cosi0) / (1 + $cosi0);
    my $c6 = $c4 * $sini0;
    $self->{debug} and warn <<eod;
Debug sgp initialization -
        A0 = $a0
        C5 = $c5
        C6 = $c6
        D10 = $d10
        D20 = $d20
        D30 = $d30
        D40 = $d40
        OMGDT = $omgdt
        Q0 = $q0
        XLO = $xlo
        XNODOT = $xnodot
eod
    {
	a0 => $a0,
	c5 => $c5,
	c6 => $c6,
	d10 => $d10,
	d20 => $d20,
	d30 => $d30,
	d40 => $d40,
	omgdt => $omgdt,
	q0 => $q0,
	xlo => $xlo,
	xnodot => $xnodot,
	};
    };


#*	Update for secular gravity and atmospheric drag.

my $a = $self->{meanmotion} +
	(2 * $self->{firstderivative} +
	3 * $self->{secondderivative} * $tsince) * $tsince;
$a = $parm->{a0} * ($self->{meanmotion} / $a) ** SGP_TOTHRD;
my $e = $a > $parm->{q0} ? 1 - $parm->{q0} / $a : SGP_E6A;
my $p = $a * (1 - $e * $e);
my $xnodes = $self->{rightascension} + $parm->{xnodot} * $tsince;
my $omgas = $self->{argumentofperigee} + $parm->{omgdt} * $tsince;
my $xls = mod2pi ($parm->{xlo} + ($self->{meanmotion} + $parm->{omgdt} +
	$parm->{xnodot} + ($self->{firstderivative} +
	$self->{secondderivative} * $tsince) * $tsince) * $tsince);
$self->{debug} and warn <<eod;
Debug sgp - atmospheric drag and gravity
        TSINCE = $tsince
        A = $a
        E = $e
        P = $p
        XNODES = $xnodes
        OMGAS = $omgas
        XLS = $xls
eod


#*	Long period periodics.

my $axnsl = $e * cos ($omgas);
my $aynsl = $e * sin ($omgas) - $parm->{c6} / $p;
my $xl = mod2pi ($xls - $parm->{c5} / $p * $axnsl);
$self->{debug} and warn <<eod;
Debug sgp - long period periodics
        AXNSL = $axnsl
        AYNSL = $aynsl
        XL = $xl
eod


#*	Solve Kepler's equation.

my $u = mod2pi ($xl - $xnodes);
my ($item3, $eo1, $tem5) = (0, $u, 1);
my ($sineo1, $coseo1);
while (1) {
    $sineo1 = sin ($eo1);
    $coseo1 = cos ($eo1);
    last if abs ($tem5) < SGP_E6A || $item3++ >= 10;
    $tem5 = 1 - $coseo1 * $axnsl - $sineo1 * $aynsl;
    $tem5 = ($u - $aynsl * $coseo1 + $axnsl * $sineo1 - $eo1) / $tem5;
    my $tem2 = abs ($tem5);
    $tem2 > 1 and $tem5 = $tem2 / $tem5;
    $eo1 += $tem5;
    }
$self->{debug} and warn <<eod;
Debug sgp - solve equation of Kepler
        U = $u
        EO1 = $eo1
        SINEO1 = $sineo1
        COSEO1 = $coseo1
eod


#*	Short period preliminary quantities.

my $ecose = $axnsl * $coseo1 + $aynsl * $sineo1;
my $esine = $axnsl * $sineo1 - $aynsl * $coseo1;
my $el2 = $axnsl * $axnsl + $aynsl * $aynsl;
my $pl = $a * (1 - $el2);
my $pl2 = $pl * $pl;
my $r = $a * (1 - $ecose);
my $rdot = SGP_XKE * sqrt ($a) / $r * $esine;
my $rvdot = SGP_XKE * sqrt ($pl) / $r;
my $temp = $esine / (1 + sqrt (1 - $el2));
my $sinu = $a / $r * ($sineo1 - $aynsl - $axnsl * $temp);
my $cosu = $a / $r * ($coseo1 - $axnsl + $aynsl * $temp);
my $su = _actan ($sinu, $cosu);
$self->{debug} and warn <<eod;
Debug sgp - short period preliminary quantities
        PL2 = $pl2
        R = $r
        RDOT = $rdot
        RVDOT = $rvdot
        SINU = $sinu
        COSU = $cosu
        SU = $su
eod


#*	Update for short periodics.

my $sin2u = ($cosu + $cosu) * $sinu;
my $cos2u = 1 - 2 * $sinu * $sinu;
my $rk = $r + $parm->{d10} / $pl * $cos2u;
my $uk = $su - $parm->{d20} / $pl2 * $sin2u;
my $xnodek = $xnodes + $parm->{d30} * $sin2u / $pl2;
my $xinck = $self->{inclination} + $parm->{d40} / $pl2 * $cos2u;


#* 	Orientation vectors.

my $sinuk = sin ($uk);
my $cosuk = cos ($uk);
my $sinnok = sin ($xnodek);
my $cosnok = cos ($xnodek);
my $sinik = sin ($xinck);
my $cosik = cos ($xinck);
my $xmx = - $sinnok * $cosik;
my $xmy = $cosnok * $cosik;
my $ux = $xmx * $sinuk + $cosnok * $cosuk;
my $uy = $xmy * $sinuk + $sinnok * $cosuk;
my $uz = $sinik * $sinuk;
my $vx = $xmx * $cosuk - $cosnok * $sinuk;
my $vy = $xmy * $cosuk - $sinnok * $sinuk;
my $vz = $sinik * $cosuk;


#*	Position and velocity.

my $x = $rk * $ux;
my $y = $rk * $uy;
my $z = $rk * $uz;
my $xdot = $rdot * $ux;
my $ydot = $rdot * $uy;
my $zdot = $rdot * $uz;
$xdot = $rvdot * $vx + $xdot;
$ydot = $rvdot * $vy + $ydot;
$zdot = $rvdot * $vz + $zdot;

@_ = ($self, $x, $y, $z, $xdot, $ydot, $zdot, $time);
goto &_convert_out;
}


=item $tle = $tle->sgp4($time)

This method calculates the position of the body described by the TLE
object at the given time, using the SGP4 model. The universal time of
the object is set to $time, and the 'equinox_dynamical' attribute is set
to the current value of the 'epoch_dynamical' attribute.

The result is the original object reference. See the L</DESCRIPTION>
heading above for how to retrieve the coordinates you just calculated.

"Spacetrack Report Number 3" (see "Acknowledgments") says that this
model can be used only for near-earth orbits.

=cut

sub sgp4 {
my $self = shift;
my $time = shift;
my $tsince = ($time - $self->{epoch}) / 60;	# Calc. is in minutes.


#>>>	Rather than use a separate indicator argument to trigger
#>>>	initialization of the model, we use the Orcish maneuver to
#>>>	retrieve the results of initialization, performing the
#>>>	calculations if needed. -- TRW

my $parm = $self->{&TLE_INIT}{TLE_sgp4} ||= do {
    $self->is_deep and croak <<EOD;
Error - The SGP4 model is not valid for deep space objects.
        Use the SDP4 or SDP8 models instead.
EOD


#*	Recover original mean motion (XNODP) and semimajor axis (AODP)
#*	from input elements.

    my $a1 = (SGP_XKE / $self->{meanmotion}) ** SGP_TOTHRD;
    my $cosi0 = cos ($self->{inclination});
    my $theta2 = $cosi0 * $cosi0;
    my $x3thm1 = 3 * $theta2 - 1;
    my $eosq = $self->{eccentricity} * $self->{eccentricity};
    my $beta02 = 1 - $eosq;
    my $beta0 = sqrt ($beta02);
    my $del1 = 1.5 * SGP_CK2 * $x3thm1 / ($a1 * $a1 * $beta0 * $beta02);
    my $a0 = $a1 * (1 - $del1 * (.5 * SGP_TOTHRD + $del1 * (1 + 134 / 81 * $del1)));
    my $del0 = 1.5 * SGP_CK2 * $x3thm1 / ($a0 * $a0 * $beta0 * $beta02);
    my $xnodp = $self->{meanmotion} / (1 + $del0);
    my $aodp = $a0 / (1 - $del0);


#*	Initialization

#*	For perigee less than 220 kilometers, the ISIMP flag is set and
#*	the equations are truncated to linear variation in sqrt(A) and
#*	quadratic variation in mean anomaly. Also, the C3 term, the
#*	delta omega term, and the delta M term are dropped.

#>>>	Note that the original code sets ISIMP to 1 or 0, but we just
#>>>	set $isimp to true or false. - TRW

    my $isimp = ($aodp * (1 - $self->{eccentricity}) / SGP_AE) <
	(220 / SGP_XKMPER + SGP_AE);


#*	For perigee below 156 KM, the values of
#*	S and QOMS2T are altered.

    my $s4 = SGP_S;
    my $qoms24 = SGP_QOMS2T;
    my $perige = ($aodp * (1 - $self->{eccentricity}) - SGP_AE) * SGP_XKMPER;
    unless ($perige >= 156) {
	$s4 = $perige > 98 ? $perige - 78 : 20;
	$qoms24 = ((120 - $s4) * SGP_AE / SGP_XKMPER) ** 4;
	$s4 = $s4 / SGP_XKMPER + SGP_AE;
	}
    my $pinvsq = 1 / ($aodp * $aodp * $beta02 * $beta02);
    my $tsi = 1 / ($aodp - $s4);
    my $eta = $aodp * $self->{eccentricity} * $tsi;
    my $etasq = $eta * $eta;
    my $eeta = $self->{eccentricity} * $eta;
    my $psisq = abs (1 - $etasq);
    my $coef = $qoms24 * $tsi ** 4;
    my $coef1 = $coef / $psisq ** 3.5;
    my $c2 = $coef1 * $xnodp * ($aodp * (1 + 1.5 * $etasq + $eeta * (4 + $etasq)) + .75 *
	SGP_CK2 * $tsi / $psisq * $x3thm1 * (8 + 3 * $etasq * (8 + $etasq)));
    my $c1 = $self->{bstardrag} * $c2;
    my $sini0 = sin ($self->{inclination});
    my $a3ovk2 = - SGP_XJ3 / SGP_CK2 * SGP_AE ** 3;
    my $c3 = $coef * $tsi * $a3ovk2 * $xnodp * SGP_AE * $sini0 / $self->{eccentricity};
    my $x1mth2 = 1 - $theta2;
    my $c4 = 2 * $xnodp * $coef1 * $aodp * $beta02 * ($eta *
	(2 + .5 * $etasq) + $self->{eccentricity} * (.5 + 2 * $etasq) - 2 * SGP_CK2 * $tsi /
	($aodp * $psisq) * (-3 * $x3thm1 * (1 - 2 * $eeta + $etasq *
	(1.5 - .5 * $eeta)) + .75 * $x1mth2 * (2 * $etasq - $eeta *
	(1 + $etasq)) * cos (2 * $self->{argumentofperigee})));
    my $c5 = 2 * $coef1 * $aodp * $beta02 * (1 + 2.75 * ($etasq + $eeta) + $eeta * $etasq);
    my $theta4 = $theta2 * $theta2;
    my $temp1 = 3 * SGP_CK2 * $pinvsq * $xnodp;
    my $temp2 = $temp1 * SGP_CK2 * $pinvsq;
    my $temp3 = 1.25 * SGP_CK4 * $pinvsq * $pinvsq * $xnodp;
    my $xmdot = $xnodp + .5 * $temp1 * $beta0 * $x3thm1 + .0625 * $temp2 * $beta0 *
	(13 - 78 * $theta2 + 137 * $theta4);
    my $x1m5th = 1 - 5 * $theta2;
    my $omgdot = -.5 * $temp1 * $x1m5th + .0625 * $temp2 * (7 - 114 * $theta2 +
	395 * $theta4) + $temp3 * (3 - 36 * $theta2 + 49 * $theta4);
    my $xhdot1 = - $temp1 * $cosi0;
    my $xnodot = $xhdot1 + (.5 * $temp2 * (4 - 19 * $theta2) + 2 * $temp3 * (3 -
	7 * $theta2)) * $cosi0;
    my $omgcof = $self->{bstardrag} * $c3 * cos ($self->{argumentofperigee});
    my $xmcof = - SGP_TOTHRD * $coef * $self->{bstardrag} * SGP_AE / $eeta;
    my $xnodcf = 3.5 * $beta02 * $xhdot1 * $c1;
    my $t2cof = 1.5 * $c1;
    my $xlcof = .125 * $a3ovk2 * $sini0 * (3 + 5 * $cosi0) / (1 + $cosi0);
    my $aycof = .25 * $a3ovk2 * $sini0;
    my $delmo = (1 + $eta * cos ($self->{meananomaly})) ** 3;
    my $sinmo = sin ($self->{meananomaly});
    my $x7thm1 = 7 * $theta2 - 1;
    my ($d2, $d3, $d4, $t3cof, $t4cof, $t5cof);
    $isimp or do {
	my $c1sq = $c1 * $c1;
	$d2 = 4 * $aodp * $tsi * $c1sq;
	my $temp = $d2 * $tsi * $c1 / 3;
	$d3 = (17 * $aodp + $s4) * $temp;
	$d4 = .5 * $temp * $aodp * $tsi * (221 * $aodp + 31 * $s4) * $c1;
	$t3cof = $d2 + 2 * $c1sq;
	$t4cof = .25 * (3 * $d3 * $c1 * (12 * $d2 + 10 * $c1sq));
	$t5cof = .2 * (3 * $d4 + 12 * $c1 * $d3 + 6 * $d2 * $d2 + 15 * $c1sq * (
	    2 * $d2 + $c1sq));
	};
    $self->{debug} and print <<eod;
Debug SGP4 - Initialize
    AODP = $aodp
    AYCOF = $aycof
    C1 = $c1
    C4 = $c4
    C5 = $c5
    COSIO = $cosi0
    D2 = @{[defined $d2 ? $d2 : 'undef']}
    D3 = @{[defined $d3 ? $d3 : 'undef']}
    D4 = @{[defined $d4 ? $d4 : 'undef']}
    DELMO = $delmo
    ETA = $eta
    ISIMP = $isimp
    OMGCOF = $omgcof
    OMGDOT = $omgdot
    SINIO = $sini0
    SINMO = $sinmo
    T2COF = @{[defined $t2cof ? $t2cof : 'undef']}
    T3COF = @{[defined $t3cof ? $t3cof : 'undef']}
    T4COF = @{[defined $t4cof ? $t4cof : 'undef']}
    T5COF = @{[defined $t5cof ? $t5cof : 'undef']}
    X1MTH2 = $x1mth2
    X3THM1 = $x3thm1
    X7THM1 = $x7thm1
    XLCOF = $xlcof
    XMCOF = $xmcof
    XMDOT = $xmdot
    XNODCF = $xnodcf
    XNODOT = $xnodot
    XNODP = $xnodp
eod
    {
	aodp => $aodp,
	aycof => $aycof,
	c1 => $c1,
	c4 => $c4,
	c5 => $c5,
	cosi0 => $cosi0,
	d2 => $d2,
	d3 => $d3,
	d4 => $d4,
	delmo => $delmo,
	eta => $eta,
	isimp => $isimp,
	omgcof => $omgcof,
	omgdot => $omgdot,
	sini0 => $sini0,
	sinmo => $sinmo,
	t2cof => $t2cof,
	t3cof => $t3cof,
	t4cof => $t4cof,
	t5cof => $t5cof,
	x1mth2 => $x1mth2,
	x3thm1 => $x3thm1,
	x7thm1 => $x7thm1,
	xlcof => $xlcof,
	xmcof => $xmcof,
	xmdot => $xmdot,
	xnodcf => $xnodcf,
	xnodot => $xnodot,
	xnodp => $xnodp,
	};
    };


#*	Update for secular gravity and atmospheric drag.

my $xmdf = $self->{meananomaly} + $parm->{xmdot} * $tsince;
my $omgadf = $self->{argumentofperigee} + $parm->{omgdot} * $tsince;
my $xnoddf = $self->{rightascension} + $parm->{xnodot} * $tsince;
my $omega = $omgadf;
my $xmp = $xmdf;
my $tsq = $tsince * $tsince;
my $xnode = $xnoddf + $parm->{xnodcf} * $tsq;
my $tempa = 1 - $parm->{c1} * $tsince;
my $tempe = $self->{bstardrag} * $parm->{c4} * $tsince;
my $templ = $parm->{t2cof} * $tsq;
$parm->{isimp} or do {
    my $delomg = $parm->{omgcof} * $tsince;
    my $delm = $parm->{xmcof} * ((1 + $parm->{eta} * cos($xmdf)) ** 3 - $parm->{delmo});
    my $temp = $delomg + $delm;
    $xmp = $xmdf + $temp;
    $omega = $omgadf - $temp;
    my $tcube = $tsq * $tsince;
    my $tfour = $tsince * $tcube;
    $tempa = $tempa - $parm->{d2} * $tsq - $parm->{d3} * $tcube - $parm->{d4} * $tfour;
    $tempe = $tempe + $self->{bstardrag} * $parm->{c5} * (sin($xmp) - $parm->{sinmo});
    $templ = $templ + $parm->{t3cof} * $tcube + $tfour * ($parm->{t4cof} + $tsince * $parm->{t5cof});
    };
my $a = $parm->{aodp} * $tempa ** 2;
my $e = $self->{eccentricity} - $tempe;
my $xl = $xmp + $omega + $xnode + $parm->{xnodp} * $templ;
die <<eod if $e > 1 || $e < -1;
Error - Effective eccentricity > 1
    ID = @{[$self->get ('id')]}
    Epoch = @{[scalar gmtime $self->get ('epoch')]} GMT
    \$self->{bstardrag} = $self->{bstardrag}
    \$parm->{c4} = $parm->{c4}
    \$tsince = $tsince
    \$tempe = \$self->{bstardrag} * \$parm->{c4} * \$tsince
    \$tempe = $tempe
    \$self->{eccentricity} = $self->{eccentricity}
    \$e = \$self->{eccentricity} - \$tempe
    \$e = $e
    Either this object represents a bad set of elements, or you are
    using it beyond its "best by" date ("expiry date" in some dialects
    of English).
eod
my $beta = sqrt(1 - $e * $e);
$self->{debug} and print <<eod;
Debug SGP4 - Before xn,
    XKE = @{[SGP_XKE]}
    A = $a
    TEMPA = $tempa
    AODP = $parm->{aodp}
eod
my $xn = SGP_XKE / $a ** 1.5;


#*	Long period periodics

my $axn = $e * cos($omega);
my $temp = 1 / ($a * $beta * $beta);
my $xll = $temp * $parm->{xlcof} * $axn;
my $aynl = $temp * $parm->{aycof};
my $xlt = $xl + $xll;
my $ayn = $e * sin($omega) + $aynl;


#*	Solve Kepler's equation.

my $capu = mod2pi($xlt - $xnode);
my $temp2 = $capu;
my ($temp3, $temp4, $temp5, $temp6, $sinepw, $cosepw);
for (my $i = 0; $i < 10; $i++) {
    $sinepw = sin($temp2);
    $cosepw = cos($temp2);
    $temp3 = $axn * $sinepw;
    $temp4 = $ayn * $cosepw;
    $temp5 = $axn * $cosepw;
    $temp6 = $ayn * $sinepw;
    my $epw = ($capu - $temp4 + $temp3 - $temp2) / (1 - $temp5 - $temp6) + $temp2;
    abs ($epw - $temp2) <= SGP_E6A and last;
    $temp2 = $epw;
    }


#*	Short period preliminary quantities.

my $ecose = $temp5 + $temp6;
my $esine = $temp3 - $temp4;
my $elsq = $axn * $axn + $ayn * $ayn;
$temp = 1 - $elsq;
my $pl = $a * $temp;
my $r = $a * (1 - $ecose);
my $temp1 = 1 / $r;
my $rdot = SGP_XKE * sqrt($a) * $esine * $temp1;
my $rfdot = SGP_XKE * sqrt($pl) * $temp1;
$temp2 = $a * $temp1;
my $betal = sqrt($temp);
$temp3 = 1 / (1 + $betal);
my $cosu = $temp2 * ($cosepw - $axn + $ayn * $esine * $temp3);
my $sinu = $temp2 * ($sinepw - $ayn - $axn * $esine * $temp3);
my $u = _actan($sinu,$cosu);
my $sin2u = 2 * $sinu * $cosu;
my $cos2u = 2 * $cosu * $cosu - 1;
$temp = 1 / $pl;
$temp1 = SGP_CK2 * $temp;
$temp2 = $temp1 * $temp;


#*	Update for short periodics

my $rk = $r * (1 - 1.5 * $temp2 * $betal * $parm->{x3thm1}) + .5 * $temp1 * $parm->{x1mth2} * $cos2u;
my $uk = $u - .25 * $temp2 * $parm->{x7thm1} * $sin2u;
my $xnodek = $xnode + 1.5 * $temp2 * $parm->{cosi0} * $sin2u;
my $xinck = $self->{inclination} + 1.5 * $temp2 * $parm->{cosi0} * $parm->{sini0} * $cos2u;
my $rdotk = $rdot - $xn * $temp1 * $parm->{x1mth2} * $sin2u;
my $rfdotk = $rfdot + $xn * $temp1 * ($parm->{x1mth2} * $cos2u + 1.5 * $parm->{x3thm1});


#*	Orientation vectors

my $sinuk = sin ($uk);
my $cosuk = cos ($uk);
my $sinik = sin ($xinck);
my $cosik = cos ($xinck);
my $sinnok = sin ($xnodek);
my $cosnok = cos ($xnodek);
my $xmx = - $sinnok * $cosik;
my $xmy = $cosnok * $cosik;
my $ux = $xmx * $sinuk + $cosnok * $cosuk;
my $uy = $xmy * $sinuk + $sinnok * $cosuk;
my $uz = $sinik * $sinuk;
my $vx = $xmx * $cosuk - $cosnok * $sinuk;
my $vy = $xmy * $cosuk - $sinnok * $sinuk;
my $vz = $sinik * $cosuk;


#*	Position and velocity

my $x = $rk * $ux;
my $y = $rk * $uy;
my $z = $rk * $uz;
my $xdot = $rdotk * $ux + $rfdotk * $vx;
my $ydot = $rdotk * $uy + $rfdotk * $vy;
my $zdot = $rdotk * $uz + $rfdotk * $vz;

@_ = ($self, $x, $y, $z, $xdot, $ydot, $zdot, $time);
goto &_convert_out;
}




=item $tle = $tle->sdp4($time)

This method calculates the position of the body described by the TLE
object at the given time, using the SDP4 model. The universal time of
the object is set to $time, and the 'equinox_dynamical' attribute is set
to the current value of the 'epoch_dynamical' attribute.

The result is the original object reference. You need to call one of
the Astro::Coord::ECI methods (e.g. geodetic () or equatorial ()) to
retrieve the position you just calculated.

"Spacetrack Report Number 3" (see "Acknowledgments") says that this
model can be used only for deep-space orbits.

=cut

sub sdp4 {
my $self = shift;
my $time = shift;
my $tsince = ($time - $self->{epoch}) / 60;	# Calc. is in minutes.


#>>>	Rather than use a separate indicator argument to trigger
#>>>	initialization of the model, we use the Orcish maneuver to
#>>>	retrieve the results of initialization, performing the
#>>>	calculations if needed. -- TRW

my $parm = $self->{&TLE_INIT}{TLE_sdp4} ||= do {
    $self->is_deep or croak <<EOD;
Error - The SGP4 model is not valid for near-earth objects.
        Use the SGP, SGP4, or SGP8 models instead.
EOD

#*      Recover original mean motion (XNODP) and semimajor axis (AODP)
#*      from input elements.

    my $a1 = (SGP_XKE / $self->{meanmotion}) ** SGP_TOTHRD;
    my $cosi0 = cos ($self->{inclination});
    my $theta2 = $cosi0 * $cosi0;
    my $x3thm1 = 3 * $theta2 - 1;
    my $eosq = $self->{eccentricity} * $self->{eccentricity};
    my $beta02 = 1 - $eosq;
    my $beta0 = sqrt ($beta02);
    my $del1 = 1.5 * SGP_CK2 * $x3thm1 / ($a1 * $a1 * $beta0 * $beta02);
    my $a0 = $a1 * (1 - $del1 * (.5 * SGP_TOTHRD + $del1 * (1 + 134 / 81 * $del1)));
    my $del0 = 1.5 * SGP_CK2 * $x3thm1 / ($a0 * $a0 * $beta0 * $beta02);
    my $xnodp = $self->{meanmotion} / (1 + $del0);
# no problem here - we know this because AODP is returned.
    my $aodp = $a0 / (1 - $del0);


#*	Initialization

#*	For perigee below 156 KM, the values of
#*	S and QOMS2T are altered

    my $s4 = SGP_S;
    my $qoms24 = SGP_QOMS2T;
    my $perige = ($aodp * (1 - $self->{eccentricity}) - SGP_AE) * SGP_XKMPER;
    unless ($perige >= 156) {
	$s4 = $perige > 98 ? $perige - 78 : 20;
	$qoms24 = ((120 - $s4) * SGP_AE / SGP_XKMPER) ** 4;
	$s4 = $s4 / SGP_XKMPER + SGP_AE;
	}
    my $pinvsq = 1 / ($aodp * $aodp * $beta02 * $beta02);
    my $sing = sin ($self->{argumentofperigee});
    my $cosg = cos ($self->{argumentofperigee});
    my $tsi = 1 / ($aodp - $s4);
    my $eta = $aodp * $self->{eccentricity} * $tsi;
    my $etasq = $eta * $eta;
    my $eeta = $self->{eccentricity} * $eta;
    my $psisq = abs (1 - $etasq);
    my $coef = $qoms24 * $tsi ** 4;
    my $coef1 = $coef / $psisq ** 3.5;
    my $c2 = $coef1 * $xnodp * ($aodp * (1 + 1.5 * $etasq + $eeta *
	(4 + $etasq)) + .75 * SGP_CK2 * $tsi / $psisq * $x3thm1 *
	(8 + 3 * $etasq * (8 + $etasq)));
# minor problem here
    my $c1 = $self->{bstardrag} * $c2;
    my $sini0 = sin ($self->{inclination});
    my $a3ovk2 = - SGP_XJ3 / SGP_CK2 * SGP_AE ** 3;
    my $x1mth2 = 1 - $theta2;
    my $c4 = 2 * $xnodp * $coef1 * $aodp * $beta02 * ($eta * (2 + .5 *
	$etasq) + $self->{eccentricity} * (.5 + 2 * $etasq) -
	2 * SGP_CK2 * $tsi / ($aodp * $psisq) * ( - 3 * $x3thm1 *
	(1 - 2 * $eeta + $etasq * (1.5 - .5 * $eeta)) + .75 * $x1mth2 *
	(2 * $etasq - $eeta * (1 + $etasq)) *
	cos (2 * $self->{argumentofperigee})));
    my $theta4 = $theta2 * $theta2;
    my $temp1 = 3 * SGP_CK2 * $pinvsq * $xnodp;
    my $temp2 = $temp1 * SGP_CK2 * $pinvsq;
    my $temp3 = 1.25 * SGP_CK4 * $pinvsq * $pinvsq * $xnodp;
    my $xmdot = $xnodp + .5 * $temp1 * $beta0 * $x3thm1 +
	.0625 * $temp2 * $beta0 * (13 - 78 * $theta2 + 137 * $theta4);
    my $x1m5th = 1 - 5 * $theta2;
    my $omgdot = - .5 * $temp1 * $x1m5th +
	.0625 * $temp2 * (7 - 114 * $theta2 + 395 * $theta4) +
	$temp3 * (3 - 36 * $theta2 + 49 * $theta4);
    my $xhdot1 = - $temp1 * $cosi0;
    my $xnodot = $xhdot1 + (.5 * $temp2 * (4 - 19 * $theta2) +
	2 * $temp3 * (3 - 7 * $theta2)) * $cosi0;
# problem here (inherited from C1 problem?)
    my $xnodcf = 3.5 * $beta02 * $xhdot1 * $c1;
# problem here (inherited from C1 problem?)
    my $t2cof = 1.5 * $c1;
    my $xlcof = .125 * $a3ovk2 * $sini0 * (3 + 5 * $cosi0) / (1 + $cosi0);
    my $aycof = .25 * $a3ovk2 * $sini0;
    my $x7thm1 = 7 * $theta2 - 1;
    $self->{&TLE_INIT}{TLE_deep} = {$self->_dpinit ($eosq, $sini0, $cosi0, $beta0,
	$aodp, $theta2, $sing, $cosg, $beta02, $xmdot, $omgdot,
	$xnodot, $xnodp)},

    $self->{debug} and print <<eod;
Debug SDP4 - Initialize
    AODP = $aodp
    AYCOF = $aycof
    C1 = $c1  << 2.45532e-06 in test_sgp-c-lib
    c2 = $c2  << 0.000171569 in test_sgp-c-lib
    C4 = $c4
    COSIO = $cosi0
    ETA = $eta
    OMGDOT = $omgdot
    s4 = $s4
    SINIO = $sini0
    T2COF = @{[defined $t2cof ? $t2cof : 'undef']}  << 3.68298e-06 in test_sgp-c-lib
    X1MTH2 = $x1mth2
    X3THM1 = $x3thm1
    X7THM1 = $x7thm1
    XLCOF = $xlcof
    XMDOT = $xmdot
    XNODCF = $xnodcf  << -1.40764e-11 in test_sgp-c-lib
    XNODOT = $xnodot
    XNODP = $xnodp
eod
    {
	aodp => $aodp,
	aycof => $aycof,
	c1 => $c1,
	c4 => $c4,
###	c5 => $c5,
	cosi0 => $cosi0,
###	d2 => $d2,
###	d3 => $d3,
###	d4 => $d4,
###	delmo => $delmo,
	eta => $eta,
###	isimp => $isimp,
###	omgcof => $omgcof,
	omgdot => $omgdot,
	sini0 => $sini0,
###	sinmo => $sinmo,
	t2cof => $t2cof,
###	t3cof => $t3cof,
###	t4cof => $t4cof,
###	t5cof => $t5cof,
	x1mth2 => $x1mth2,
	x3thm1 => $x3thm1,
	x7thm1 => $x7thm1,
	xlcof => $xlcof,
###	xmcof => $xmcof,
	xmdot => $xmdot,
	xnodcf => $xnodcf,
	xnodot => $xnodot,
	xnodp => $xnodp,
	};
    };
my $dpsp = $self->{&TLE_INIT}{TLE_deep};


#* UPDATE FOR SECULAR GRAVITY AND ATMOSPHERIC DRAG

my $xmdf = $self->{meananomaly} + $parm->{xmdot} * $tsince;
my $omgadf = $self->{argumentofperigee} + $parm->{omgdot} * $tsince;
my $xnoddf = $self->{rightascension} + $parm->{xnodot} * $tsince;
my $tsq = $tsince * $tsince;
my $xnode = $xnoddf + $parm->{xnodcf} * $tsq;
my $tempa = 1 - $parm->{c1} * $tsince;
my $tempe = $self->{bstardrag} * $parm->{c4} * $tsince;
my $templ = $parm->{t2cof} * $tsq;
my $xn = $parm->{xnodp};
my ($em, $xinc);	# Hope this is right.
$self->_dpsec (\$xmdf, \$omgadf, \$xnode, \$em, \$xinc, \$xn, $tsince);
my $a = (SGP_XKE / $xn) ** SGP_TOTHRD * $tempa ** 2;
my $e = $em - $tempe;
my $xmam = $xmdf + $parm->{xnodp} * $templ;
$self->_dpper (\$e, \$xinc, \$omgadf, \$xnode, \$xmam, $tsince);
my $xl = $xmam + $omgadf + $xnode;
my $beta = sqrt (1 - $e * $e);
$xn = SGP_XKE / $a ** 1.5;


#* LONG PERIOD PERIODICS

my $axn = $e * cos ($omgadf);
my $temp = 1 / ($a * $beta * $beta);
my $xll = $temp * $parm->{xlcof} * $axn;
my $aynl = $temp * $parm->{aycof};
my $xlt = $xl + $xll;
my $ayn = $e * sin ($omgadf) + $aynl;


#* SOLVE KEPLERS EQUATION

my $capu = mod2pi ($xlt - $xnode);
my $temp2 = $capu;
my ($epw, $sinepw, $cosepw, $temp3, $temp4, $temp5, $temp6);
for (my $i = 0; $i < 10; $i++) {
    $sinepw = sin ($temp2);
    $cosepw = cos ($temp2);
    $temp3 = $axn * $sinepw;
    $temp4 = $ayn * $cosepw;
    $temp5 = $axn * $cosepw;
    $temp6 = $ayn * $sinepw;
    $epw = ($capu - $temp4 + $temp3 - $temp2) / (1 - $temp5 - $temp6) + $temp2;
    last if (abs ($epw - $temp2) <= SGP_E6A);
    $temp2 = $epw;
    }


#* SHORT PERIOD PRELIMINARY QUANTITIES

my $ecose = $temp5 + $temp6;
my $esine = $temp3 - $temp4;
my $elsq = $axn * $axn + $ayn * $ayn;
$temp = 1 - $elsq;
my $pl = $a * $temp;
my $r = $a * (1 - $ecose);
my $temp1 = 1 / $r;
my $rdot = SGP_XKE * sqrt ($a) * $esine * $temp1;
my $rfdot = SGP_XKE * sqrt ($pl) * $temp1;
$temp2 = $a * $temp1;
my $betal = sqrt ($temp);
$temp3 = 1 / (1 + $betal);
my $cosu = $temp2 * ($cosepw - $axn + $ayn * $esine * $temp3);
my $sinu = $temp2 * ($sinepw - $ayn - $axn * $esine * $temp3);
my $u = _actan ($sinu,$cosu);
my $sin2u = 2 * $sinu * $cosu;
my $cos2u = 2 * $cosu * $cosu - 1;
$temp = 1 / $pl;
$temp1 = SGP_CK2 * $temp;
$temp2 = $temp1 * $temp;


#* UPDATE FOR SHORT PERIODICS

my $rk = $r * (1 - 1.5 * $temp2 * $betal * $parm->{x3thm1}) + .5 * $temp1 * $parm->{x1mth2} * $cos2u;
my $uk = $u - .25 * $temp2 * $parm->{x7thm1} * $sin2u;
my $xnodek = $xnode + 1.5 * $temp2 * $parm->{cosi0} * $sin2u;
my $xinck = $xinc + 1.5 * $temp2 * $parm->{cosi0} * $parm->{sini0} * $cos2u;
my $rdotk = $rdot - $xn * $temp1 * $parm->{x1mth2} * $sin2u;
my $rfdotk = $rfdot + $xn * $temp1 * ($parm->{x1mth2} * $cos2u + 1.5 * $parm->{x3thm1});


#* ORIENTATION VECTORS

my $sinuk = sin ($uk);
my $cosuk = cos ($uk);
my $sinik = sin ($xinck);
my $cosik = cos ($xinck);
my $sinnok = sin ($xnodek);
my $cosnok = cos ($xnodek);
my $xmx = - $sinnok * $cosik;
my $xmy = $cosnok * $cosik;
my $ux = $xmx * $sinuk + $cosnok * $cosuk;
my $uy = $xmy * $sinuk + $sinnok * $cosuk;
my $uz = $sinik * $sinuk;
my $vx = $xmx * $cosuk - $cosnok * $sinuk;
my $vy = $xmy * $cosuk - $sinnok * $sinuk;
my $vz = $sinik * $cosuk;


#* POSITION AND VELOCITY

my $x = $rk * $ux;
my $y = $rk * $uy;
my $z = $rk * $uz;
my $xdot = $rdotk * $ux + $rfdotk * $vx;
my $ydot = $rdotk * $uy + $rfdotk * $vy;
my $zdot = $rdotk * $uz + $rfdotk * $vz;

@_ = ($self, $x, $y, $z, $xdot, $ydot, $zdot, $time);
goto &_convert_out;
}


=item $tle = $tle->sgp8($time)

This method calculates the position of the body described by the TLE
object at the given time, using the SGP8 model. The universal time of
the object is set to $time, and the 'equinox_dynamical' attribute is set
to the current value of the 'epoch_dynamical' attribute.

The result is the original object reference. You need to call one of
the Astro::Coord::ECI methods (e.g. geodetic () or equatorial ()) to
retrieve the position you just calculated.

"Spacetrack Report Number 3" (see "Acknowledgments") says that this
model can be used only for near-earth orbits.

=cut

sub sgp8 {
my $self = shift;
my $time = shift;
my $tsince = ($time - $self->{epoch}) / 60;	# Calc. is in minutes.


#>>>	Rather than use a separate indicator argument to trigger
#>>>	initialization of the model, we use the Orcish maneuver to
#>>>	retrieve the results of initialization, performing the
#>>>	calculations if needed. -- TRW

my $parm = $self->{&TLE_INIT}{TLE_sgp8} ||= do {
    $self->is_deep and croak <<EOD;
Error - The SGP8 model is not valid for deep space objects.
        Use the SDP4 or SDP8 models instead.
EOD


#*	RECOVER ORIGINAL MEAN MOTION (XNODP) AND SEMIMAJOR AXIS (AODP)
#*	FROM INPUT ELEMENTS --------- CALCULATE BALLISTIC COEFFICIENT
#*	(B TERM) FROM INPUT B* DRAG TERM

    my $a1 = (SGP_XKE / $self->{meanmotion}) ** SGP_TOTHRD;
    my $cosi = cos ($self->{inclination});
    my $theta2 = $cosi * $cosi;
    my $tthmun = 3 * $theta2 - 1;
    my $eosq = $self->{eccentricity} * $self->{eccentricity};
    my $beta02 = 1 - $eosq;
    my $beta0 = sqrt ($beta02);
    my $del1 = 1.5 * SGP_CK2 * $tthmun / ($a1 * $a1 * $beta0 * $beta02);
    my $a0 = $a1 * (1 - $del1 * (.5 * SGP_TOTHRD +
	$del1 * (1 + 134 / 81 * $del1)));
    my $del0 = 1.5 * SGP_CK2 * $tthmun / ($a0 * $a0 * $beta0 * $beta02);
    my $aodp = $a0 / (1 - $del0);
    my $xnodp = $self->{meanmotion} / (1 + $del0);
    my $b = 2 * $self->{bstardrag} / SGP_RHO;


#*	INITIALIZATION

    my $isimp = 0;
    my $po = $aodp * $beta02;
    my $pom2 = 1 / ($po * $po);
    my $sini = sin ($self->{inclination});
    my $sing = sin ($self->{argumentofperigee});
    my $cosg = cos ($self->{argumentofperigee});
    my $temp = .5 * $self->{inclination};
    my $sinio2 = sin ($temp);
    my $cosio2 = cos ($temp);
    my $theta4 = $theta2 ** 2;
    my $unm5th = 1 - 5 * $theta2;
    my $unmth2 = 1 - $theta2;
    my $a3cof = - SGP_XJ3 / SGP_CK2 * SGP_AE ** 3;
    my $pardt1 = 3 * SGP_CK2 * $pom2 * $xnodp;
    my $pardt2 = $pardt1 * SGP_CK2 * $pom2;
    my $pardt4 = 1.25 * SGP_CK4 * $pom2 * $pom2 * $xnodp;
    my $xmdt1 = .5 * $pardt1 * $beta0 * $tthmun;
    my $xgdt1 = - .5 * $pardt1 * $unm5th;
    my $xhdt1 = - $pardt1 * $cosi;
    my $xlldot = $xnodp + $xmdt1 + .0625 * $pardt2 * $beta0 *
	(13 - 78 * $theta2 + 137 * $theta4);
    my $omgdt = $xgdt1 + .0625 * $pardt2 * (7 - 114 * $theta2 +
	395 * $theta4) + $pardt4 * (3 - 36 * $theta2 + 49 * $theta4);
    my $xnodot = $xhdt1 + (.5 * $pardt2 * (4 - 19 * $theta2) +
	2 * $pardt4 * (3 - 7 * $theta2)) * $cosi;
    my $tsi = 1 / ($po - SGP_S);
    my $eta = $self->{eccentricity} * SGP_S * $tsi;
    my $eta2 = $eta ** 2;
    my $psim2 = abs (1 / (1 - $eta2));
    my $alpha2 = 1 + $eosq;
    my $eeta = $self->{eccentricity} * $eta;
    my $cos2g = 2 * $cosg ** 2 - 1;
    my $d5 = $tsi * $psim2;
    my $d1 = $d5 / $po;
    my $d2 = 12 + $eta2 * (36 + 4.5 * $eta2);
    my $d3 = $eta2 * (15 + 2.5 * $eta2);
    my $d4 = $eta * (5 + 3.75 * $eta2);
    my $b1 = SGP_CK2 * $tthmun;
    my $b2 = - SGP_CK2 * $unmth2;
    my $b3 = $a3cof * $sini;
    my $c0 = .5 * $b * SGP_RHO * SGP_QOMS2T * $xnodp * $aodp *
	$tsi ** 4 * $psim2 ** 3.5 / sqrt ($alpha2);
    my $c1 = 1.5 * $xnodp * $alpha2 ** 2 * $c0;
    my $c4 = $d1 * $d3 * $b2;
    my $c5 = $d5 * $d4 * $b3;
    my $xndt = $c1 * ( (2 + $eta2 * (3 + 34 * $eosq) +
	5 * $eeta * (4 + $eta2) + 8.5 * $eosq) + $d1 * $d2 * $b1 +
	$c4 * $cos2g + $c5 * $sing);
    my $xndtn = $xndt / $xnodp;


#*	IF DRAG IS VERY SMALL, THE ISIMP FLAG IS SET AND THE
#*	EQUATIONS ARE TRUNCATED TO LINEAR VARIATION IN MEAN
#*	MOTION AND QUADRATIC VARIATION IN MEAN ANOMALY

#>>>	Note that the simplified version of the code has been swapped
#>>>	above the full version to preserve the sense of the comment.

    my ($ed, $edot, $gamma, $pp, $ovgpp, $qq, $xnd);
    if (abs ($xndtn * SGP_XMNPDA) < 2.16e-3) {
	$isimp = 1;
	$edot = - SGP_TOTHRD * $xndtn * (1 - $self->{eccentricity});
	}
      else {
	my $d6 = $eta * (30 + 22.5 * $eta2);
	my $d7 = $eta * (5 + 12.5 * $eta2);
	my $d8 = 1 + $eta2 * (6.75 + $eta2);
	my $c8 = $d1 * $d7 * $b2;
	my $c9 = $d5 * $d8 * $b3;
	$edot = - $c0 * ($eta * (4 + $eta2 +
		$eosq * (15.5 + 7 * $eta2)) +
		$self->{eccentricity} * (5 + 15 * $eta2) +
		$d1 * $d6 * $b1 + $c8 * $cos2g + $c9 * $sing);
	my $d20 = .5 * SGP_TOTHRD * $xndtn;
	my $aldtal = $self->{eccentricity} * $edot / $alpha2;
	my $tsdtts = 2 * $aodp * $tsi * ($d20 * $beta02 +
		$self->{eccentricity} * $edot);
	my $etdt = ($edot + $self->{eccentricity} * $tsdtts)
		* $tsi * SGP_S;
	my $psdtps = - $eta * $etdt * $psim2;
	my $sin2g = 2 * $sing * $cosg;
	my $c0dtc0 = $d20 + 4 * $tsdtts - $aldtal - 7 * $psdtps;
	my $c1dtc1 = $xndtn + 4 * $aldtal + $c0dtc0;
	my $d9 = $eta * (6 + 68 * $eosq) +
		$self->{eccentricity} * (20 + 15 * $eta2);
	my $d10 = 5 * $eta * (4 + $eta2) +
		$self->{eccentricity} * (17 + 68 * $eta2);
	my $d11 = $eta * (72 + 18 * $eta2);
	my $d12 = $eta * (30 + 10 * $eta2);
	my $d13 = 5 + 11.25 * $eta2;
	my $d14 = $tsdtts - 2 * $psdtps;
	my $d15 = 2 * ($d20 + $self->{eccentricity} * $edot / $beta02);
	my $d1dt = $d1 * ($d14 + $d15);
	my $d2dt = $etdt * $d11;
	my $d3dt = $etdt * $d12;
	my $d4dt = $etdt * $d13;
	my $d5dt = $d5 * $d14;
	my $c4dt = $b2 * ($d1dt * $d3 + $d1 * $d3dt);
	my $c5dt = $b3 * ($d5dt * $d4 + $d5 * $d4dt);
	my $d16 = $d9 * $etdt + $d10 * $edot +
		$b1 * ($d1dt * $d2 + $d1 * $d2dt) + $c4dt * $cos2g +
		$c5dt * $sing +
		$xgdt1 * ($c5 * $cosg - 2 * $c4 * $sin2g);
	my $xnddt = $c1dtc1 * $xndt + $c1 * $d16;
	my $eddot = $c0dtc0 * $edot -
		$c0 * ((4 + 3 * $eta2 + 30 * $eeta +
		$eosq * (15.5 + 21 * $eta2)) * $etdt +
		(5 + 15 * $eta2 + $eeta * (31 + 14 * $eta2)) * $edot +
		$b1 * ($d1dt * $d6 + $d1 * $etdt * (30 + 67.5 *
		$eta2)) + $b2 * ($d1dt * $d7 +
		$d1 * $etdt * (5 + 37.5 * $eta2)) * $cos2g +
		$b3 * ($d5dt * $d8 + $d5 * $etdt * $eta * (13.5 +
		4 * $eta2)) * $sing +
		$xgdt1 * ($c9 * $cosg - 2 * $c8 * $sin2g));
	my $d25 = $edot ** 2;
	my $d17 = $xnddt / $xnodp - $xndtn ** 2;
	my $tsddts = 2 * $tsdtts * ($tsdtts - $d20) + $aodp * $tsi *
	    (SGP_TOTHRD * $beta02 * $d17 - 4 * $d20 *
	    $self->{eccentricity} * $edot + 2 *
	    ($d25 + $self->{eccentricity} * $eddot));
	my $etddt = ($eddot + 2 * $edot * $tsdtts) * $tsi * SGP_S + $tsddts * $eta;
	my $d18 = $tsddts - $tsdtts ** 2;
	my $d19 = - $psdtps ** 2 / $eta2 - $eta * $etddt * $psim2 - $psdtps ** 2;
	my $d23 = $etdt * $etdt;
	my $d1ddt = $d1dt * ($d14 + $d15) + $d1 * ($d18 - 2 * $d19 +
	    SGP_TOTHRD * $d17 + 2 * ($alpha2 * $d25 / $beta02 +
	    $self->{eccentricity} * $eddot) / $beta02);
	my $xntrdt = $xndt * (2 * SGP_TOTHRD * $d17 + 3 * ($d25 +
	    $self->{eccentricity} * $eddot) / $alpha2 -
	    6 * $aldtal ** 2 + 4 * $d18 - 7 * $d19 ) +
	    $c1dtc1 * $xnddt + $c1 * ($c1dtc1 * $d16 + $d9 * $etddt +
	    $d10 * $eddot + $d23 * (6 + 30 * $eeta + 68 * $eosq) +
	    $etdt * $edot * (40 + 30 * $eta2 + 272 * $eeta) +
	    $d25 * (17 + 68 * $eta2) + $b1 * ($d1ddt * $d2 +
	    2 * $d1dt * $d2dt + $d1 * ($etddt * $d11 +
	    $d23 * (72 + 54 * $eta2))) + $b2 * ($d1ddt * $d3 +
	    2 * $d1dt * $d3dt + $d1 * ($etddt * $d12 +
	    $d23 * (30 + 30 * $eta2))) * $cos2g +
	    $b3 * (($d5dt * $d14 + $d5 * ($d18 - 2 * $d19)) * $d4 +
	    2 * $d4dt * $d5dt + $d5 * ($etddt * $d13 +
	    22.5 * $eta * $d23)) * $sing + $xgdt1 * ((7 * $d20 +
	    4 * $self->{eccentricity} * $edot / $beta02) *
	    ($c5 * $cosg - 2 * $c4 * $sin2g) + ( (2 * $c5dt * $cosg -
	    4 * $c4dt * $sin2g) - $xgdt1 * ($c5 * $sing +
	    4 * $c4 * $cos2g))));
	my $tmnddt = $xnddt * 1.e9;
	my $temp = $tmnddt ** 2 - $xndt * 1.e18 * $xntrdt;
	$pp = ($temp + $tmnddt ** 2) / $temp;
	$gamma = - $xntrdt / ($xnddt * ($pp - 2.));
	$xnd = $xndt / ($pp * $gamma);
	$qq = 1 - $eddot / ($edot * $gamma);
	$ed = $edot / ($qq * $gamma);
	$ovgpp = 1 / ($gamma * ($pp + 1.));
	}
    $self->{debug} and print <<eod;
Debug SGP8 - Initialize
    A3COF = @{[defined $a3cof ? $a3cof : 'undef']}
    COSI = @{[defined $cosi ? $cosi : 'undef']}
    COSIO2 = @{[defined $cosio2 ? $cosio2 : 'undef']}
    ED = @{[defined $ed ? $ed : 'undef']}
    EDOT = @{[defined $edot ? $edot : 'undef']}
    GAMMA = @{[defined $gamma ? $gamma : 'undef']}
    ISIMP = @{[defined $isimp ? $isimp : 'undef']}
    OMGDT = @{[defined $omgdt ? $omgdt : 'undef']}
    OVGPP = @{[defined $ovgpp ? $ovgpp : 'undef']}
    PP = @{[defined $pp ? $pp : 'undef']}
    QQ = @{[defined $qq ? $qq : 'undef']}
    SINI = @{[defined $sini ? $sini : 'undef']}
    SINIO2 = @{[defined $sinio2 ? $sinio2 : 'undef']}
    THETA2 = @{[defined $theta2 ? $theta2 : 'undef']}
    TTHMUN = @{[defined $tthmun ? $tthmun : 'undef']}
    UNM5TH = @{[defined $unm5th ? $unm5th : 'undef']}
    UNMTH2 = @{[defined $unmth2 ? $unmth2 : 'undef']}
    XGDT1 = @{[defined $xgdt1 ? $xgdt1 : 'undef']}
    XHDT1 = @{[defined $xhdt1 ? $xhdt1 : 'undef']}
    XLLDOT = @{[defined $xlldot ? $xlldot : 'undef']}
    XMDT1 = @{[defined $xmdt1 ? $xmdt1 : 'undef']}
    XND = @{[defined $xnd ? $xnd : 'undef']}
    XNDT = @{[defined $xndt ? $xndt : 'undef']}
    XNODOT = @{[defined $xnodot ? $xnodot : 'undef']}
    XNODP = @{[defined $xnodp ? $xnodp : 'undef']}
eod
    {
	a3cof => $a3cof,
	cosi => $cosi,
	cosio2 => $cosio2,
	ed => $ed,
	edot => $edot,
	gamma => $gamma,
	isimp => $isimp,
	omgdt => $omgdt,
	ovgpp => $ovgpp,
	pp => $pp,
	qq => $qq,
	sini => $sini,
	sinio2 => $sinio2,
	theta2 => $theta2,
	tthmun => $tthmun,
	unm5th => $unm5th,
	unmth2 => $unmth2,
	xgdt1 => $xgdt1,
	xhdt1 => $xhdt1,
	xlldot => $xlldot,
	xmdt1 => $xmdt1,
	xnd => $xnd,
	xndt => $xndt,
	xnodot => $xnodot,
	xnodp => $xnodp,
	};
    };


#*	UPDATE FOR SECULAR GRAVITY AND ATMOSPHERIC DRAG

my $xmam = mod2pi ($self->{meananomaly} + $parm->{xlldot} * $tsince);
my $omgasm = $self->{argumentofperigee} + $parm->{omgdt} * $tsince;
my $xnodes = $self->{rightascension} + $parm->{xnodot} * $tsince;

#>>>	The simplified and full logic have been swapped for clarity.

my ($xn, $em, $z1);
if ($parm->{isimp}) {
    $xn = $parm->{xnodp} + $parm->{xndt} * $tsince;
    $em = $self->{eccentricity} + $parm->{edot} * $tsince;
    $z1 = .5 * $parm->{xndt} * $tsince * $tsince;
    }
  else {
    my $temp = 1 - $parm->{gamma} * $tsince;
    my $temp1 = $temp ** $parm->{pp};
    $xn = $parm->{xnodp} + $parm->{xnd} * (1 - $temp1);
    $em = $self->{eccentricity} + $parm->{ed} * (1 - $temp ** $parm->{qq});
    $z1 = $parm->{xnd} * ($tsince + $parm->{ovgpp} * ($temp * $temp1 - 1.));
    }
my $z7 = 3.5 * SGP_TOTHRD * $z1 / $parm->{xnodp};
$xmam = mod2pi ($xmam + $z1 + $z7 * $parm->{xmdt1});
$omgasm = $omgasm + $z7 * $parm->{xgdt1};
$xnodes = $xnodes + $z7 * $parm->{xhdt1};


#*      SOLVE KEPLERS EQUATION

my $zc2 = $xmam + $em * sin ($xmam) * (1 + $em * cos ($xmam));
my ($cose, $sine, $zc5);
for (my $i = 0; $i < 10; $i++) {
    $sine = sin ($zc2);
    $cose = cos ($zc2);
    $zc5 = 1 / (1 - $em * $cose);
    my $cape = ($xmam + $em * $sine - $zc2) * $zc5 + $zc2;
    last if (abs ($cape - $zc2) <= SGP_E6A);
    $zc2 = $cape;
    }


#*      SHORT PERIOD PRELIMINARY QUANTITIES

my $am = (SGP_XKE / $xn) ** SGP_TOTHRD;
my $beta2m = 1 - $em * $em;
my $sinos = sin ($omgasm);
my $cosos = cos ($omgasm);
my $axnm = $em * $cosos;
my $aynm = $em * $sinos;
my $pm = $am * $beta2m;
my $g1 = 1 / $pm;
my $g2 = .5 * SGP_CK2 * $g1;
my $g3 = $g2 * $g1;
my $beta = sqrt ($beta2m);
my $g4 = .25 * $parm->{a3cof} * $parm->{sini};
my $g5 = .25 * $parm->{a3cof} * $g1;
my $snf = $beta * $sine * $zc5;
my $csf = ($cose - $em) * $zc5;
my $fm = _actan ($snf,$csf);
my $snfg = $snf * $cosos + $csf * $sinos;
my $csfg = $csf * $cosos - $snf * $sinos;
my $sn2f2g = 2 * $snfg * $csfg;
my $cs2f2g = 2 * $csfg ** 2 - 1;
my $ecosf = $em * $csf;
my $g10 = $fm - $xmam + $em * $snf;
my $rm = $pm / (1 + $ecosf);
my $aovr = $am / $rm;
my $g13 = $xn * $aovr;
my $g14 = - $g13 * $aovr;
my $dr = $g2 * ($parm->{unmth2} * $cs2f2g - 3 * $parm->{tthmun}) -
	$g4 * $snfg;
my $diwc = 3 * $g3 * $parm->{sini} * $cs2f2g - $g5 * $aynm;
my $di = $diwc * $parm->{cosi};


#*      UPDATE FOR SHORT PERIOD PERIODICS

my $sni2du = $parm->{sinio2} * ($g3 * (.5 * (1 - 7 * $parm->{theta2}) *
	$sn2f2g - 3 * $parm->{unm5th} * $g10) - $g5 * $parm->{sini} *
	$csfg * (2 + $ecosf)) - .5 * $g5 * $parm->{theta2} * $axnm /
	$parm->{cosio2};
my $xlamb = $fm + $omgasm + $xnodes + $g3 * (.5 * (1 + 6 *
	$parm->{cosi} - 7 * $parm->{theta2}) * $sn2f2g - 3 *
	($parm->{unm5th} + 2 * $parm->{cosi}) * $g10) +
	$g5 * $parm->{sini} * ($parm->{cosi} * $axnm /
	(1 + $parm->{cosi}) - (2 + $ecosf) * $csfg);
my $y4 = $parm->{sinio2} * $snfg + $csfg * $sni2du +
	.5 * $snfg * $parm->{cosio2} * $di;
my $y5 = $parm->{sinio2} * $csfg - $snfg * $sni2du +
	.5 * $csfg * $parm->{cosio2} * $di;
my $r = $rm + $dr;
my $rdot = $xn * $am * $em * $snf / $beta + $g14 *
	(2 * $g2 * $parm->{unmth2} * $sn2f2g + $g4 * $csfg);
my $rvdot = $xn * $am ** 2 * $beta / $rm + $g14 * $dr +
	$am * $g13 * $parm->{sini} * $diwc;


#*      ORIENTATION VECTORS

my $snlamb = sin ($xlamb);
my $cslamb = cos ($xlamb);
my $temp = 2 * ($y5 * $snlamb - $y4 * $cslamb);
my $ux = $y4 * $temp + $cslamb;
my $vx = $y5 * $temp - $snlamb;
$temp = 2 * ($y5 * $cslamb + $y4 * $snlamb);
my $uy = - $y4 * $temp + $snlamb;
my $vy = - $y5 * $temp + $cslamb;
$temp = 2 * sqrt (1 - $y4 * $y4 - $y5 * $y5);
my $uz = $y4 * $temp;
my $vz = $y5 * $temp;


#*      POSITION AND VELOCITY

my $x = $r * $ux;
my $y = $r * $uy;
my $z = $r * $uz;
my $xdot = $rdot * $ux + $rvdot * $vx;
my $ydot = $rdot * $uy + $rvdot * $vy;
my $zdot = $rdot * $uz + $rvdot * $vz;

@_ = ($self, $x, $y, $z, $xdot, $ydot, $zdot, $time);
goto &_convert_out;
}


=item $tle = $tle->sdp8($time)

This method calculates the position of the body described by the TLE
object at the given time, using the SDP8 model. The universal time of
the object is set to $time, and the 'equinox_dynamical' attribute is set
to the current value of the 'epoch_dynamical' attribute.

The result is the original object reference. You need to call one of
the Astro::Coord::ECI methods (e.g. geodetic () or equatorial ()) to
retrieve the position you just calculated.

"Spacetrack Report Number 3" (see "Acknowledgments") says that this
model can be used only for near-earth orbits.

=cut

sub sdp8 {
my $self = shift;
my $time = shift;
my $tsince = ($time - $self->{epoch}) / 60;	# Calc. is in minutes.


#>>>	Rather than use a separate indicator argument to trigger
#>>>	initialization of the model, we use the Orcish maneuver to
#>>>	retrieve the results of initialization, performing the
#>>>	calculations if needed. -- TRW

my $parm = $self->{&TLE_INIT}{TLE_sdp8} ||= do {
    $self->is_deep or croak <<EOD;
Error - The SDP8 model is not valid for near-earth objects.
        Use the SGP, SGP4 or SGP8 models instead.
EOD


#*      RECOVER ORIGINAL MEAN MOTION (XNODP) AND SEMIMAJOR AXIS (AODP)
#*      FROM INPUT ELEMENTS --------- CALCULATE BALLISTIC COEFFICIENT
#* (B TERM) FROM INPUT B* DRAG TERM

    my $a1 = (SGP_XKE / $self->{meanmotion}) ** SGP_TOTHRD;
    my $cosi = cos ($self->{inclination});
    my $theta2 = $cosi * $cosi;
    my $tthmun = 3 * $theta2 - 1;
    my $eosq = $self->{eccentricity} * $self->{eccentricity};
    my $beta02 = 1 - $eosq;
    my $beta0 = sqrt ($beta02);
    my $del1 = 1.5 * SGP_CK2 * $tthmun / ($a1 * $a1 * $beta0 * $beta02);
    my $a0 = $a1 * (1 - $del1 * (.5 * SGP_TOTHRD + $del1 * (1 + 134 / 81 * $del1)));
    my $del0 = 1.5 * SGP_CK2 * $tthmun / ($a0 * $a0 * $beta0 * $beta02);
    my $aodp = $a0 / (1 - $del0);
    my $xnodp = $self->{meanmotion} / (1 + $del0);
    my $b = 2 * $self->{bstardrag} / SGP_RHO;


#*      INITIALIZATION

    my $po = $aodp * $beta02;
    my $pom2 = 1 / ($po * $po);
    my $sini = sin ($self->{inclination});
    my $sing = sin ($self->{argumentofperigee});
    my $cosg = cos ($self->{argumentofperigee});
    my $temp = .5 * $self->{inclination};
    my $sinio2 = sin ($temp);
    my $cosio2 = cos ($temp);
    my $theta4 = $theta2 ** 2;
    my $unm5th = 1 - 5 * $theta2;
    my $unmth2 = 1 - $theta2;
    my $a3cof = - SGP_XJ3 / SGP_CK2 * SGP_AE ** 3;
    my $pardt1 = 3 * SGP_CK2 * $pom2 * $xnodp;
    my $pardt2 = $pardt1 * SGP_CK2 * $pom2;
    my $pardt4 = 1.25 * SGP_CK4 * $pom2 * $pom2 * $xnodp;
    my $xmdt1 = .5 * $pardt1 * $beta0 * $tthmun;
    my $xgdt1 = - .5 * $pardt1 * $unm5th;
    my $xhdt1 = - $pardt1 * $cosi;
    my $xlldot = $xnodp + $xmdt1 + .0625 * $pardt2 * $beta0 * (13 - 78 * $theta2 + 137 * $theta4);
    my $omgdt = $xgdt1 + .0625 * $pardt2 * (7 - 114 * $theta2 +
        395 * $theta4) + $pardt4 * (3 - 36 * $theta2 + 49 * $theta4);
    my $xnodot = $xhdt1 + (.5 * $pardt2 * (4 - 19 * $theta2) + 2 * $pardt4 * (3 - 7 * $theta2)) * $cosi;
    my $tsi = 1 / ($po - SGP_S);
    my $eta = $self->{eccentricity} * SGP_S * $tsi;
    my $eta2 = $eta ** 2;
    my $psim2 = abs (1 / (1 - $eta2));
    my $alpha2 = 1 + $eosq;
    my $eeta = $self->{eccentricity} * $eta;
    my $cos2g = 2 * $cosg ** 2 - 1;
    my $d5 = $tsi * $psim2;
    my $d1 = $d5 / $po;
    my $d2 = 12 + $eta2 * (36 + 4.5 * $eta2);
    my $d3 = $eta2 * (15 + 2.5 * $eta2);
    my $d4 = $eta * (5 + 3.75 * $eta2);
    my $b1 = SGP_CK2 * $tthmun;
    my $b2 = - SGP_CK2 * $unmth2;
    my $b3 = $a3cof * $sini;
    my $c0 = .5 * $b * SGP_RHO * SGP_QOMS2T * $xnodp * $aodp *
	$tsi ** 4 * $psim2 ** 3.5 / sqrt ($alpha2);
    my $c1 = 1.5 * $xnodp * $alpha2 ** 2 * $c0;
    my $c4 = $d1 * $d3 * $b2;
    my $c5 = $d5 * $d4 * $b3;
    my $xndt = $c1 * ( (2 + $eta2 * (3 + 34 * $eosq) +
	5 * $eeta * (4 + $eta2) + 8.5 * $eosq) + $d1 * $d2 * $b1 +
	$c4 * $cos2g + $c5 * $sing);
    my $xndtn = $xndt / $xnodp;
    my $edot = - SGP_TOTHRD * $xndtn * (1 - $self->{eccentricity});
    $self->{&TLE_INIT}{TLE_deep} = {$self->_dpinit ($eosq, $sini, $cosi, $beta0,
	$aodp, $theta2, $sing, $cosg, $beta02, $xlldot, $omgdt,
	$xnodot, $xnodp)},
    {
	a3cof => $a3cof,
	cosi => $cosi,
	cosio2 => $cosio2,
###	ed => $ed,
	edot => $edot,
###	gamma => $gamma,
###	isimp => $isimp,
	omgdt => $omgdt,
###	ovgpp => $ovgpp,
###	pp => $pp,
###	qq => $qq,
	sini => $sini,
	sinio2 => $sinio2,
	theta2 => $theta2,
	tthmun => $tthmun,
	unm5th => $unm5th,
	unmth2 => $unmth2,
	xgdt1 => $xgdt1,
	xhdt1 => $xhdt1,
	xlldot => $xlldot,
	xmdt1 => $xmdt1,
###	xnd => $xnd,
	xndt => $xndt,
	xnodot => $xnodot,
	xnodp => $xnodp,
	};
    };
my $dpsp = $self->{&TLE_INIT}{TLE_deep};


#*	UPDATE FOR SECULAR GRAVITY AND ATMOSPHERIC DRAG

my $z1 = .5 * $parm->{xndt} * $tsince * $tsince;
my $z7 = 3.5 * SGP_TOTHRD * $z1 / $parm->{xnodp};
my $xmamdf = $self->{meananomaly} + $parm->{xlldot} * $tsince;
my $omgasm = $self->{argumentofperigee} + $parm->{omgdt} * $tsince + $z7 * $parm->{xgdt1};
my $xnodes = $self->{rightascension} + $parm->{xnodot} * $tsince + $z7 * $parm->{xhdt1};
my $xn = $parm->{xnodp};
my ($em, $xinc);
$self->_dpsec (\$xmamdf, \$omgasm, \$xnodes, \$em, \$xinc, \$xn, $tsince);
$xn = $xn + $parm->{xndt} * $tsince;
$em = $em + $parm->{edot} * $tsince;
my $xmam = $xmamdf + $z1 + $z7 * $parm->{xmdt1};
$self->_dpper (\$em, \$xinc, \$omgasm, \$xnodes, \$xmam, $tsince);
$xmam = mod2pi ($xmam);


#*	SOLVE KEPLERS EQUATION

my $zc2 = $xmam + $em * sin ($xmam) * (1 + $em * cos ($xmam));
my ($cose, $sine, $zc5);
for (my $i = 0; $i < 10; $i++) {
    $sine = sin ($zc2);
    $cose = cos ($zc2);
    $zc5 = 1 / (1 - $em * $cose);
    my $cape = ($xmam + $em * $sine - $zc2) * $zc5 + $zc2;
    last if (abs ($cape - $zc2) <= SGP_E6A);
    $zc2 = $cape;
    }


#*	SHORT PERIOD PRELIMINARY QUANTITIES

my $am = (SGP_XKE / $xn) ** SGP_TOTHRD;
my $beta2m = 1 - $em * $em;
my $sinos = sin ($omgasm);
my $cosos = cos ($omgasm);
my $axnm = $em * $cosos;
my $aynm = $em * $sinos;
my $pm = $am * $beta2m;
my $g1 = 1 / $pm;
my $g2 = .5 * SGP_CK2 * $g1;
my $g3 = $g2 * $g1;
my $beta = sqrt ($beta2m);
my $g4 = .25 * $parm->{a3cof} * $parm->{sini};
my $g5 = .25 * $parm->{a3cof} * $g1;
my $snf = $beta * $sine * $zc5;
my $csf = ($cose - $em) * $zc5;
my $fm = _actan ($snf,$csf);
my $snfg = $snf * $cosos + $csf * $sinos;
my $csfg = $csf * $cosos - $snf * $sinos;
my $sn2f2g = 2 * $snfg * $csfg;
my $cs2f2g = 2 * $csfg ** 2 - 1;
my $ecosf = $em * $csf;
my $g10 = $fm - $xmam + $em * $snf;
my $rm = $pm / (1 + $ecosf);
my $aovr = $am / $rm;
my $g13 = $xn * $aovr;
my $g14 = - $g13 * $aovr;
my $dr = $g2 * ($parm->{unmth2} * $cs2f2g - 3 * $parm->{tthmun}) -
	$g4 * $snfg;
my $diwc = 3 * $g3 * $parm->{sini} * $cs2f2g - $g5 * $aynm;
my $di = $diwc * $parm->{cosi};
my $sini2 = sin (.5 * $xinc);


#*	UPDATE FOR SHORT PERIOD PERIODICS

my $sni2du = $parm->{sinio2} * ($g3 * (.5 * (1 - 7 * $parm->{theta2}) *
	$sn2f2g - 3 * $parm->{unm5th} * $g10) - $g5 * $parm->{sini} *
	$csfg * (2 + $ecosf)) - .5 * $g5 * $parm->{theta2} * $axnm /
	$parm->{cosio2};
my $xlamb = $fm + $omgasm + $xnodes + $g3 * (.5 * (1 +
	6 * $parm->{cosi} - 7 * $parm->{theta2}) * $sn2f2g -
	3 * ($parm->{unm5th} + 2 * $parm->{cosi}) * $g10) +
	$g5 * $parm->{sini} * ($parm->{cosi} * $axnm /
	(1 + $parm->{cosi}) - (2 + $ecosf) * $csfg);
my $y4 = $sini2 * $snfg + $csfg * $sni2du +
	.5 * $snfg * $parm->{cosio2} * $di;
my $y5 = $sini2 * $csfg - $snfg * $sni2du +
	.5 * $csfg * $parm->{cosio2} * $di;
my $r = $rm + $dr;
my $rdot = $xn * $am * $em * $snf / $beta +
	$g14 * (2 * $g2 * $parm->{unmth2} * $sn2f2g + $g4 * $csfg);
my $rvdot = $xn * $am ** 2 * $beta / $rm + $g14 * $dr +
	$am * $g13 * $parm->{sini} * $diwc;


#*	ORIENTATION VECTORS

my $snlamb = sin ($xlamb);
my $cslamb = cos ($xlamb);
my $temp = 2 * ($y5 * $snlamb - $y4 * $cslamb);
my $ux = $y4 * $temp + $cslamb;
my $vx = $y5 * $temp - $snlamb;
$temp = 2 * ($y5 * $cslamb + $y4 * $snlamb);
my $uy = - $y4 * $temp + $snlamb;
my $vy = - $y5 * $temp + $cslamb;
$temp = 2 * sqrt (1 - $y4 * $y4 - $y5 * $y5);
my $uz = $y4 * $temp;
my $vz = $y5 * $temp;


#*	POSITION AND VELOCITY

my $x = $r * $ux;
my $y = $r * $uy;
my $z = $r * $uz;
my $xdot = $rdot * $ux + $rvdot * $vx;
my $ydot = $rdot * $uy + $rvdot * $vy;
my $zdot = $rdot * $uz + $rvdot * $vz;

@_ = ($self, $x, $y, $z, $xdot, $ydot, $zdot, $time);
goto &_convert_out;
}


=item $self->time_set();

This method sets the coordinates of the object to whatever is
computed by the model specified by the model attribute. The
'equinox_dynamical' attribute is set to the current value of the
'epoch_dynamical' attribute.

Although there is no reason this method can not be called directly, it
exists to take advantage of the hook in the B<Astro::Coord::ECI>
object, to allow the position of the body to be computed when the
time of the object is set.

=cut

sub time_set {
my $self = shift;
my $model = $self->{model} or return;
$self->$model ($self->universal);
}


#######################################################################

#	The deep-space routines

use constant DS_ZNS => 1.19459E-5;
use constant DS_C1SS => 2.9864797E-6;
use constant DS_ZES => .01675;
use constant DS_ZNL => 1.5835218E-4;
use constant DS_C1L => 4.7968065E-7;
use constant DS_ZEL => .05490;
use constant DS_ZCOSIS => .91744867;
use constant DS_ZSINIS => .39785416;
use constant DS_ZSINGS => -.98088458;
use constant DS_ZCOSGS => .1945905;
use constant DS_ZCOSHS => 1.0;
use constant DS_ZSINHS => 0.0;
use constant DS_Q22 => 1.7891679E-6;
use constant DS_Q31 => 2.1460748E-6;
use constant DS_Q33 => 2.2123015E-7;
use constant DS_G22 => 5.7686396;
use constant DS_G32 => 0.95240898;
use constant DS_G44 => 1.8014998;
use constant DS_G52 => 1.0508330;
use constant DS_G54 => 4.4108898;
use constant DS_ROOT22 => 1.7891679E-6;
use constant DS_ROOT32 => 3.7393792E-7;
use constant DS_ROOT44 => 7.3636953E-9;
use constant DS_ROOT52 => 1.1428639E-7;
use constant DS_ROOT54 => 2.1765803E-9;
use constant DS_THDT => 4.3752691E-3;

#	_dpinit
#
#	the corresponding FORTRAN IV simply leaves values in variables
#	for the use of the other deep-space routines. For the Perl
#	translation, we figure out which ones are actually used, and
#	return a list of key/value pairs to be added to the pre-
#	computed model parameters. -- TRW

sub _dpinit {
my ($self, $eqsq, $siniq, $cosiq, $rteqsq, $a0, $cosq2, $sinomo,
	$cosomo, $bsq, $xlldot, $omgdt, $xnodot, $xnodp) = @_;

my $thgr = thetag ($self->{epoch});
my $eq  =  $self->{eccentricity};
my $xnq  =  $xnodp;
my $aqnv  =  1 / $a0;
my $xqncl  =  $self->{inclination};
my $xmao = $self->{meananomaly};
my $xpidot = $omgdt + $xnodot;
my $sinq  =  sin ($self->{rightascension});
my $cosq  =  cos ($self->{rightascension});


#*	Initialize lunar & solar terms

my $day = $self->{ds50} + 18261.5;

#>>>	The original code contained here a comparison of DAY to
#>>>	uninitialized variable PREEP, and "optimized out" the
#>>>	following if they were equal. This works naturally in
#>>>	FORTRAN, which has a different concept of variable scoping.
#>>>	Rather than make this work in Perl, I have removed the
#>>>	test. As I understand the FORTRAN, it's only used if
#>>>	consecutive data sets have exactly the same epoch. Given
#>>>	that this is initialization code, the optimization is
#>>>	(I hope!) not that important, and given the mess that
#>>>	follows, its absence will not (I hope!) be noticable. - TRW

my $xnodce = 4.5236020 - 9.2422029E-4 * $day;
my $stem = sin ($xnodce);
my $ctem = cos ($xnodce);
my $zcosil = .91375164 - .03568096 * $ctem;
my $zsinil = sqrt (1 - $zcosil * $zcosil);
my $zsinhl =  .089683511 * $stem / $zsinil;
my $zcoshl = sqrt (1 - $zsinhl * $zsinhl);
my $c = 4.7199672 + .22997150 * $day;
my $gam = 5.8351514 + .0019443680 * $day;
my $zmol = mod2pi ($c - $gam);
my $zx = .39785416 * $stem / $zsinil;
my $zy = $zcoshl * $ctem + 0.91744867 * $zsinhl * $stem;
$zx = _actan ($zx, $zy);
$zx = $gam + $zx - $xnodce;
my $zcosgl = cos ($zx);
my $zsingl = sin ($zx);
my $zmos = mod2pi (6.2565837 + .017201977 * $day);

#>>>	Here endeth the optimization - only it isn't one any more
#>>>	since I removed it. - TRW

#>>>	The following loop replaces some spaghetti involving an
#>>>	assigned goto which essentially executes the same big chunk
#>>>	of obscure code twice: once for the Sun, and once for the Moon.
#>>>	The comments "Do Solar terms" and "Do Lunar terms" in the
#>>>	original apply to the first and second iterations of the loop,
#>>>	respectively. The "my" variables declared just before the "for"
#>>>	are those values computed inside the loop that are used outside
#>>>	the loop. Accumulators are set to zero. -- TRW

my $savtsn = 1.0E20;
my $xnoi = 1 / $xnq;
my ($sse, $ssi, $ssl, $ssh, $ssg) = (0, 0, 0, 0, 0);
my ($se2, $ee2, $si2, $xi2, $sl2, $xl2, $sgh2, $xgh2, $sh2, $xh2, $se3,
    $e3, $si3, $xi3, $sl3, $xl3, $sgh3, $xgh3, $sh3, $xh3, $sl4, $xl4,
    $sgh4, $xgh4);

foreach my $inputs (
	[DS_ZCOSGS, DS_ZSINGS, DS_ZCOSIS, DS_ZSINIS, $cosq, $sinq,
		DS_C1SS, DS_ZNS, DS_ZES, $zmos, 0],
	[$zcosgl, $zsingl, $zcosil, $zsinil,
		$zcoshl * $cosq + $zsinhl * $sinq,
		$sinq * $zcoshl - $cosq * $zsinhl, DS_C1L, DS_ZNL,
		DS_ZEL, $zmol, 1],
	) {


#>>>	Pick off the terms specific to the body being covered by this
#>>>	iteration. The $lunar flag was not in the original FORTRAN, but
#>>>	was added to help convert the assigned GOTOs and associated
#>>>	code into a loop. -- TRW

    my ($zcosg, $zsing, $zcosi, $zsini, $zcosh, $zsinh, $cc, $zn, $ze,
	$zmo, $lunar) = @$inputs;


#>>>	From here until the next comment of mine is essentialy
#>>>	verbatim from the original FORTRAN - or as verbatim as
#>>>	is reasonable considering that the following is Perl. -- TRW

    my $a1 = $zcosg * $zcosh + $zsing * $zcosi * $zsinh;
    my $a3 = - $zsing * $zcosh + $zcosg * $zcosi * $zsinh;
    my $a7 = - $zcosg * $zsinh + $zsing * $zcosi * $zcosh;
    my $a8 = $zsing * $zsini;
    my $a9 = $zsing * $zsinh + $zcosg * $zcosi * $zcosh;
    my $a10 = $zcosg * $zsini;
    my $a2 = $cosiq * $a7 + $siniq * $a8;
    my $a4 = $cosiq * $a9 + $siniq * $a10;
    my $a5 = - $siniq * $a7 + $cosiq * $a8;
    my $a6 = - $siniq * $a9 + $cosiq * $a10;
#C
    my $x1 = $a1 * $cosomo + $a2 * $sinomo;
    my $x2 = $a3 * $cosomo + $a4 * $sinomo;
    my $x3 = - $a1 * $sinomo + $a2 * $cosomo;
    my $x4 = - $a3 * $sinomo + $a4 * $cosomo;
    my $x5 = $a5 * $sinomo;
    my $x6 = $a6 * $sinomo;
    my $x7 = $a5 * $cosomo;
    my $x8 = $a6 * $cosomo;
#C
    my $z31 = 12 * $x1 * $x1 - 3 * $x3 * $x3;
    my $z32 = 24 * $x1 * $x2 - 6 * $x3 * $x4;
    my $z33 = 12 * $x2 * $x2 - 3 * $x4 * $x4;
    my $z1 = 3 * ($a1 * $a1 + $a2 * $a2) + $z31 * $eqsq;
    my $z2 = 6 * ($a1 * $a3 + $a2 * $a4) + $z32 * $eqsq;
    my $z3 = 3 * ($a3 * $a3 + $a4 * $a4) + $z33 * $eqsq;
    my $z11 = - 6 * $a1 * $a5 + $eqsq * ( - 24 * $x1 * $x7 - 6 * $x3 * $x5);
    my $z12 = - 6 * ($a1 * $a6 + $a3 * $a5) + $eqsq *
	( - 24 * ($x2 * $x7 + $x1 * $x8) - 6 * ($x3 * $x6 + $x4 * $x5));
    my $z13 = - 6 * $a3 * $a6 + $eqsq * ( - 24 * $x2 * $x8 - 6 * $x4 * $x6);
    my $z21 = 6 * $a2 * $a5 + $eqsq * (24 * $x1 * $x5 - 6 * $x3 * $x7);
    my $z22 = 6 * ($a4 * $a5 + $a2 * $a6) + $eqsq *
	(24 * ($x2 * $x5 + $x1 * $x6) - 6 * ($x4 * $x7 + $x3 * $x8));
    my $z23 = 6 * $a4 * $a6 + $eqsq * (24 * $x2 * $x6 - 6 * $x4 * $x8);
    $z1 = $z1 + $z1 + $bsq * $z31;
    $z2 = $z2 + $z2 + $bsq * $z32;
    $z3 = $z3 + $z3 + $bsq * $z33;
    my $s3 = $cc * $xnoi;
    my $s2 = - .5 * $s3 / $rteqsq;
    my $s4 = $s3 * $rteqsq;
    my $s1 = - 15 * $eq * $s4;
    my $s5 = $x1 * $x3 + $x2 * $x4;
    my $s6 = $x2 * $x3 + $x1 * $x4;
    my $s7 = $x2 * $x4 - $x1 * $x3;
    my $se = $s1 * $zn * $s5;
    my $si = $s2 * $zn * ($z11 + $z13);
    my $sl = - $zn * $s3 * ($z1 + $z3 - 14 - 6 * $eqsq);
    my $sgh = $s4 * $zn * ($z31 + $z33 - 6.);
    my $sh = $xqncl < 5.2359877E-2 ? 0 : - $zn * $s2 * ($z21 + $z23);
    $ee2 = 2 * $s1 * $s6;
    $e3 = 2 * $s1 * $s7;
    $xi2 = 2 * $s2 * $z12;
    $xi3 = 2 * $s2 * ($z13 - $z11);
    $xl2 = - 2 * $s3 * $z2;
    $xl3 = - 2 * $s3 * ($z3 - $z1);
    $xl4 = - 2 * $s3 * ( - 21 - 9 * $eqsq) * $ze;
    $xgh2 = 2 * $s4 * $z32;
    $xgh3 = 2 * $s4 * ($z33 - $z31);
    $xgh4 = - 18 * $s4 * $ze;
    $xh2 = - 2 * $s2 * $z22;
    $xh3 = - 2 * $s2 * ($z23 - $z21);


#>>>	The following intermediate values are used outside the loop.
#>>>	We save off the Solar values. The Lunar values remain after
#>>>	the second iteration, and are used in situ. -- TRW

    unless ($lunar) {
	$se2 = $ee2;
	$si2 = $xi2;
	$sl2 = $xl2;
	$sgh2 = $xgh2;
	$sh2 = $xh2;
	$se3 = $e3;
	$si3 = $xi3;
	$sl3 = $xl3;
	$sgh3 = $xgh3;
	$sh3 = $xh3;
	$sl4 = $xl4;
	$sgh4 = $xgh4;
	}

#>>>	Okay, now we accumulate everything that needs accumulating.
#>>>	The Lunar calculation is slightly different from the solar
#>>>	one, a problem we fix up using the introduced $lunar flag.
#>>>	-- TRW

    $sse = $sse + $se;
    $ssi = $ssi + $si;
    $ssl = $ssl + $sl;
    $ssh = $ssh + $sh / $siniq;
    $ssg = $ssg + $sgh - ($lunar ? $cosiq / $siniq * $sh : $cosiq * $ssh);

    }


#>>>	The only substantial modification in the following is the
#>>>	swapping of 24-hour and 12-hour calculations for clarity.
#>>>	-- TRW

my $iresfl = 0;
my $isynfl = 0;
my ($bfact, $xlamo);
my ($d2201, $d2211, $d3210, $d3222, $d4410, $d4422,
	$d5220, $d5232, $d5421, $d5433,
	$del1, $del2, $del3, $fasx2, $fasx4, $fasx6);

if ($xnq < .0052359877 && $xnq > .0034906585) {


#*      Synchronous resonance terms initialization.

    $iresfl = 1;
    $isynfl = 1;
    my $g200 = 1.0 + $eqsq * ( - 2.5 + .8125 * $eqsq);
    my $g310 = 1.0 + 2.0 * $eqsq;
    my $g300 = 1.0 + $eqsq * ( - 6.0 + 6.60937 * $eqsq);
    my $f220 = .75 * (1 + $cosiq) * (1 + $cosiq);
    my $f311 = .9375 * $siniq * $siniq * (1 + 3 * $cosiq) - .75 * (1 + $cosiq);
    my $f330 = 1 + $cosiq;
    $f330 = 1.875 * $f330 * $f330 * $f330;
    $del1 = 3 * $xnq * $xnq * $aqnv * $aqnv;
    $del2 = 2 * $del1 * $f220 * $g200 * DS_Q22;
    $del3 = 3 * $del1 * $f330 * $g300 * DS_Q33 * $aqnv;
    $del1 = $del1 * $f311 * $g310 * DS_Q31 * $aqnv;
    $fasx2 = .13130908;
    $fasx4 = 2.8843198;
    $fasx6 = .37448087;
    $xlamo = $xmao + $self->{rightascension} + $self->{argumentofperigee} - $thgr;
    $bfact = $xlldot + $xpidot - DS_THDT;
    $bfact = $bfact + $ssl + $ssg + $ssh;
    }

  elsif ($xnq < 8.26E-3 || $xnq > 9.24E-3 || $eq < 0.5) {


#>>>	Do nothing. The original code returned from this point,
#>>>	leaving atime, step2, stepn, stepp, xfact, xli, and xni
#>>>	uninitialized. It's a minor bit of wasted motion to
#>>>	compute these when they're not used, but this way the
#>>>	method returns from only one point, which makes the
#>>>	provision of debug output easier.

    }
  else {

#*      Geopotential resonance initialization for 12 hour orbits

    $iresfl = 1;
    my $eoc = $eq * $eqsq;
    my $g201 = - .306 - ($eq - .64) * .440;
    my ($g211, $g310, $g322, $g410, $g422, $g520);
    if ($eq <= .65) {
	$g211 = 3.616 - 13.247 * $eq + 16.290 * $eqsq;
	$g310 = - 19.302 + 117.390 * $eq - 228.419 * $eqsq + 156.591 * $eoc;
	$g322 = - 18.9068 + 109.7927 * $eq - 214.6334 * $eqsq + 146.5816 * $eoc;
	$g410 = - 41.122 + 242.694 * $eq - 471.094 * $eqsq + 313.953 * $eoc;
	$g422 = - 146.407 + 841.880 * $eq - 1629.014 * $eqsq + 1083.435 * $eoc;
	$g520 = - 532.114 + 3017.977 * $eq - 5740 * $eqsq + 3708.276 * $eoc;
	}
      else {
	$g211 = - 72.099 + 331.819 * $eq - 508.738 * $eqsq + 266.724 * $eoc;
	$g310 = - 346.844 + 1582.851 * $eq - 2415.925 * $eqsq + 1246.113 * $eoc;
	$g322 = - 342.585 + 1554.908 * $eq - 2366.899 * $eqsq + 1215.972 * $eoc;
	$g410 = - 1052.797 + 4758.686 * $eq - 7193.992 * $eqsq + 3651.957 * $eoc;
	$g422 = - 3581.69 + 16178.11 * $eq - 24462.77 * $eqsq + 12422.52 * $eoc;
	$g520 = $eq > .715 ?
	    -5149.66 + 29936.92 * $eq - 54087.36 * $eqsq + 31324.56 * $eoc :
	    1464.74 - 4664.75 * $eq + 3763.64 * $eqsq;
	}
    my ($g533, $g521, $g532);
    if ($eq < .7) {
	$g533 = - 919.2277 + 4988.61 * $eq - 9064.77 * $eqsq + 5542.21 * $eoc;
	$g521 = - 822.71072 + 4568.6173 * $eq - 8491.4146 * $eqsq + 5337.524 * $eoc;
	$g532 = - 853.666 + 4690.25 * $eq - 8624.77 * $eqsq + 5341.4 * $eoc;
	}
      else {
	$g533 = - 37995.78 + 161616.52 * $eq - 229838.2 * $eqsq + 109377.94 * $eoc;
	$g521 = - 51752.104 + 218913.95 * $eq - 309468.16 * $eqsq + 146349.42 * $eoc;
	$g532 = - 40023.88 + 170470.89 * $eq - 242699.48 * $eqsq + 115605.82 * $eoc;
	}

    my $sini2 = $siniq * $siniq;
    my $f220 = .75 * (1 + 2 * $cosiq + $cosq2);
    my $f221 = 1.5 * $sini2;
    my $f321 = 1.875 * $siniq * (1 - 2 * $cosiq - 3 * $cosq2);
    my $f322 = - 1.875 * $siniq * (1 + 2 * $cosiq - 3 * $cosq2);
    my $f441 = 35 * $sini2 * $f220;
    my $f442 = 39.3750 * $sini2 * $sini2;
    my $f522 = 9.84375 * $siniq * ($sini2 * (1 - 2 * $cosiq - 5 * $cosq2) + .33333333 * ( - 2 + 4 * $cosiq + 6 * $cosq2));
    my $f523 = $siniq * (4.92187512 * $sini2 * ( - 2 - 4 * $cosiq + 10 * $cosq2) + 6.56250012 * (1 + 2 * $cosiq - 3 * $cosq2));
    my $f542 = 29.53125 * $siniq * (2 - 8 * $cosiq + $cosq2 * ( - 12 + 8 * $cosiq + 10 * $cosq2));
    my $f543 = 29.53125 * $siniq * ( - 2 - 8 * $cosiq + $cosq2 * (12 + 8 * $cosiq - 10 * $cosq2));
    my $xno2 = $xnq * $xnq;
    my $ainv2 = $aqnv * $aqnv;
    my $temp1 = 3 * $xno2 * $ainv2;
    my $temp = $temp1 * DS_ROOT22;
    $d2201 = $temp * $f220 * $g201;
    $d2211 = $temp * $f221 * $g211;
    $temp1 = $temp1 * $aqnv;
    $temp = $temp1 * DS_ROOT32;
    $d3210 = $temp * $f321 * $g310;
    $d3222 = $temp * $f322 * $g322;
    $temp1 = $temp1 * $aqnv;
    $temp = 2 * $temp1 * DS_ROOT44;
    $d4410 = $temp * $f441 * $g410;
    $d4422 = $temp * $f442 * $g422;
    $temp1 = $temp1 * $aqnv;
    $temp = $temp1 * DS_ROOT52;
    $d5220 = $temp * $f522 * $g520;
    $d5232 = $temp * $f523 * $g532;
    $temp = 2 * $temp1 * DS_ROOT54;
    $d5421 = $temp * $f542 * $g521;
    $d5433 = $temp * $f543 * $g533;
    $xlamo = $xmao + $self->{rightascension} + $self->{rightascension} - $thgr - $thgr;
    $bfact = $xlldot + $xnodot + $xnodot - DS_THDT - DS_THDT;
    $bfact = $bfact + $ssl + $ssh + $ssh;
    }

#	$bfact won't be defined unless we're a 12- or 24-hour orbit.
my $xfact = $bfact - $xnq if defined $bfact;
#C
#C INITIALIZE INTEGRATOR
#C
my $xli = $xlamo;
my $xni = $xnq;
my $atime = 0;
my $stepp = 720;
my $stepn = -720;
my $step2 = 259200;

$self->{debug} and do {
    local $Data::Dumper::Terse = 1;
    print <<eod;
Debug _dpinit -
    atime = @{[defined $atime ? $atime : q{undef}]}
    cosiq = @{[defined $cosiq ? $cosiq : q{undef}]}
    d2201 = @{[defined $d2201 ? $d2201 : q{undef}]}
    d2211 = @{[defined $d2211 ? $d2211 : q{undef}]}
    d3210 = @{[defined $d3210 ? $d3210 : q{undef}]}
    d3222 = @{[defined $d3222 ? $d3222 : q{undef}]}
    d4410 = @{[defined $d4410 ? $d4410 : q{undef}]}
    d4422 = @{[defined $d4422 ? $d4422 : q{undef}]}
    d5220 = @{[defined $d5220 ? $d5220 : q{undef}]}
    d5232 = @{[defined $d5232 ? $d5232 : q{undef}]}
    d5421 = @{[defined $d5421 ? $d5421 : q{undef}]}
    d5433 = @{[defined $d5433 ? $d5433 : q{undef}]}
    del1  = @{[defined $del1 ? $del1 : q{undef}]}
    del2  = @{[defined $del2 ? $del2 : q{undef}]}
    del3  = @{[defined $del3 ? $del3 : q{undef}]}
    e3    = @{[defined $e3 ? $e3 : q{undef}]}
    ee2   = @{[defined $ee2 ? $ee2 : q{undef}]}
    fasx2 = @{[defined $fasx2 ? $fasx2 : q{undef}]}
    fasx4 = @{[defined $fasx4 ? $fasx4 : q{undef}]}
    fasx6 = @{[defined $fasx6 ? $fasx6 : q{undef}]}
    iresfl = @{[defined $iresfl ? $iresfl : q{undef}]}
    isynfl = @{[defined $isynfl ? $isynfl : q{undef}]}
    omgdt = @{[defined $omgdt ? $omgdt : q{undef}]}
    se2   = @{[defined $se2 ? $se2 : q{undef}]}
    se3   = @{[defined $se3 ? $se3 : q{undef}]}
    sgh2  = @{[defined $sgh2 ? $sgh2 : q{undef}]}
    sgh3  = @{[defined $sgh3 ? $sgh3 : q{undef}]}
    sgh4  = @{[defined $sgh4 ? $sgh4 : q{undef}]}
    sh2   = @{[defined $sh2 ? $sh2 : q{undef}]}
    sh3   = @{[defined $sh3 ? $sh3 : q{undef}]}
    si2   = @{[defined $si2 ? $si2 : q{undef}]}
    si3   = @{[defined $si3 ? $si3 : q{undef}]}
    siniq = @{[defined $siniq ? $siniq : q{undef}]}
    sl2   = @{[defined $sl2 ? $sl2 : q{undef}]}
    sl3   = @{[defined $sl3 ? $sl3 : q{undef}]}
    sl4   = @{[defined $sl4 ? $sl4 : q{undef}]}
    sse   = @{[defined $sse ? $sse : q{undef}]}
    ssg   = @{[defined $ssg ? $ssg : q{undef}]}  << 9.4652e-09 in test_sgp-c-lib
    ssh   = @{[defined $ssh ? $ssh : q{undef}]}
    ssi   = @{[defined $ssi ? $ssi : q{undef}]}
    ssl   = @{[defined $ssl ? $ssl : q{undef}]}
    step2 = @{[defined $step2 ? $step2 : q{undef}]}
    stepn = @{[defined $stepn ? $stepn : q{undef}]}
    stepp = @{[defined $stepp ? $stepp : q{undef}]}
    thgr  = @{[defined $thgr ? $thgr : q{undef}]}  << 1.26513 in test_sgp-c-lib
    xfact = @{[defined $xfact ? $xfact : q{undef}]}
    xgh2  = @{[defined $xgh2 ? $xgh2 : q{undef}]}
    xgh3  = @{[defined $xgh3 ? $xgh3 : q{undef}]}
    xgh4  = @{[defined $xgh4 ? $xgh4 : q{undef}]}
    xh2   = @{[defined $xh2 ? $xh2 : q{undef}]}
    xh3   = @{[defined $xh3 ? $xh3 : q{undef}]}
    xi2   = @{[defined $xi2 ? $xi2 : q{undef}]}
    xi3   = @{[defined $xi3 ? $xi3 : q{undef}]}
    xl2   = @{[defined $xl2 ? $xl2 : q{undef}]}
    xl3   = @{[defined $xl3 ? $xl3 : q{undef}]}
    xl4   = @{[defined $xl4 ? $xl4 : q{undef}]}
    xlamo = @{[defined $xlamo ? $xlamo : q{undef}]}
    xli   = @{[defined $xli ? $xli : q{undef}]}
    xni   = @{[defined $xni ? $xni : q{undef}]}
    xnq   = @{[defined $xnq ? $xnq : q{undef}]}
    zmol  = @{[defined $zmol ? $zmol : q{undef}]}
    zmos  = @{[defined $zmos ? $zmos : q{undef}]}
eod
    };

return (
    atime => $atime,
    cosiq => $cosiq,
    d2201 => $d2201,
    d2211 => $d2211,
    d3210 => $d3210,
    d3222 => $d3222,
    d4410 => $d4410,
    d4422 => $d4422,
    d5220 => $d5220,
    d5232 => $d5232,
    d5421 => $d5421,
    d5433 => $d5433,
    del1  => $del1,
    del2  => $del2,
    del3  => $del3,
    e3    => $e3,
    ee2   => $ee2,
    fasx2 => $fasx2,
    fasx4 => $fasx4,
    fasx6 => $fasx6,
    iresfl => $iresfl,
    isynfl => $isynfl,
    omgdt => $omgdt,
    se2   => $se2,
    se3   => $se3,
    sgh2  => $sgh2,
    sgh3  => $sgh3,
    sgh4  => $sgh4,
    sh2   => $sh2,
    sh3   => $sh3,
    si2   => $si2,
    si3   => $si3,
    siniq => $siniq,
    sl2   => $sl2,
    sl3   => $sl3,
    sl4   => $sl4,
    sse   => $sse,
    ssg   => $ssg,
    ssh   => $ssh,
    ssi   => $ssi,
    ssl   => $ssl,
    step2 => $step2,
    stepn => $stepn,
    stepp => $stepp,
    thgr  => $thgr,
    xfact => $xfact,
    xgh2  => $xgh2,
    xgh3  => $xgh3,
    xgh4  => $xgh4,
    xh2   => $xh2,
    xh3   => $xh3,
    xi2   => $xi2,
    xi3   => $xi3,
    xl2   => $xl2,
    xl3   => $xl3,
    xl4   => $xl4,
    xlamo => $xlamo,
    xli   => $xli,
    xni   => $xni,
    xnq   => $xnq,
    zmol  => $zmol,
    zmos  => $zmos,
    );

}


#	_dpsec

#	Compute deep space secular effects.

#	The corresponding FORTRAN was a goodly plate of spaghetti, with
#	a couple chunks of code being executed via assigned GOTOs. Not
#	only that, but most of the arguments get modified, and
#	therefore need to be passed by reference. So the corresponding
#	PERL may not end up corresponding very closely.

#	In fact, at this point in the code the only argument that is
#	NOT modified is T.

sub _dpsec {
my $self = shift;
my $dpsp = $self->{&TLE_INIT}{TLE_deep};
my ($xll, $omgasm, $xnodes, $em, $xinc, $xn, $t) = @_;
my @orig = map {defined $_ ? $_ : 'undef'}
	map {ref $_ eq 'SCALAR' ? $$_ : $_} @_
    if $self->{debug};

#* ENTRANCE FOR DEEP SPACE SECULAR EFFECTS

$$xll = $$xll + $dpsp->{ssl} * $t;
$$omgasm = $$omgasm + $dpsp->{ssg} * $t;
$$xnodes = $$xnodes + $dpsp->{ssh} * $t;
$$em = $self->{eccentricity} + $dpsp->{sse} * $t;
($$xinc = $self->{inclination} + $dpsp->{ssi} * $t) < 0 and do {
    $$xinc = - $$xinc;
    $$xnodes = $$xnodes + SGP_PI;
    $$omgasm = $$omgasm - SGP_PI;
    };

$dpsp->{iresfl} and do {

    my ($delt);
    while (1) {
	!$dpsp->{atime} || $t >= 0 && $dpsp->{atime} < 0 ||
		$t < 0 && $dpsp->{atime} >= 0 and do {

#C
#C EPOCH RESTART
#C

	    $delt = $t >= 0 ? $dpsp->{stepp} : $dpsp->{stepn};
	    $dpsp->{atime} = 0;
	    $dpsp->{xni} = $dpsp->{xnq};
	    $dpsp->{xli} = $dpsp->{xlamo};
	    last;
	    };
	abs ($t) >= abs ($dpsp->{atime}) and do {
	    $delt = $t > 0 ? $dpsp->{stepp} : $dpsp->{stepn};
	    last;
	    };
	$delt = $t > 0 ? $dpsp->{stepn} : $dpsp->{stepp};
	$self->_dps_dot ($delt);	# Calc. dot terms and integrate.
	}

    while (abs ($t - $dpsp->{atime}) >= $dpsp->{stepp}) {
	$self->_dps_dot ($delt);	# Calc. dot terms and integrate.
	}
    my $ft = $t - $dpsp->{atime};
    my ($xldot, $xndot, $xnddt) = $self->_dps_dot ();	# Calc. dot terms.
    $$xn = $dpsp->{xni} + $xndot * $ft + $xnddt * $ft * $ft * 0.5;
    my $xl = $dpsp->{xli} + $xldot * $ft + $xndot * $ft * $ft * 0.5;
    my $temp = - $$xnodes + $dpsp->{thgr} + $t * DS_THDT;
    $$xll = $dpsp->{isynfl}  ? $xl - $$omgasm + $temp : $xl + $temp + $temp;
    };

$self->{debug} and print <<eod;
Debug _dpsec -
    xll    : $orig[0] -> $$xll
    omgasm : $orig[1] -> $$omgasm
    xnodes : $orig[2] -> $$xnodes
    em     : $orig[3] -> $$em
    xinc   : $orig[4] -> $$xinc
    xn     : $orig[5] -> $$xn
    t      : $t
eod
}


#	_dps_dot

#	Calculate the dot terms for the secular effects.

#	In the original FORTRAN, this was a chunk of code followed
#	by an assigned GOTO. But here it has transmogrified into a
#	method. If an argument is passed, it is taken to be the delta
#	for an iteration of the integration step, which is done. It
#	returns xldot, xndot, and xnddt

sub _dps_dot {
my $self = shift;
my $dpsp = $self->{&TLE_INIT}{TLE_deep};


#C
#C DOT TERMS CALCULATED
#C

# We get here from either:
#   - an explicit GOTO below line 130;
#   - an explicit GOTO below line 160, which is reached from below 110 or 125.
# This is the only reference to line 152.
# XNDOT, XNDDT, and XLDOT come out of this.
#150:
my ($xndot, $xnddt);
if ($dpsp->{isynfl}) {
    $xndot = $dpsp->{del1} * sin ($dpsp->{xli} - $dpsp->{fasx2}) +
	$dpsp->{del2} * sin (2 * ($dpsp->{xli} - $dpsp->{fasx4})) +
	$dpsp->{del3} * sin (3 * ($dpsp->{xli} - $dpsp->{fasx6}));
    $xnddt = $dpsp->{del1} * cos ($dpsp->{xli} - $dpsp->{fasx2}) +
	2 * $dpsp->{del2} * cos (2 * ($dpsp->{xli} - $dpsp->{fasx4})) +
	3 * $dpsp->{del3} * cos (3 * ($dpsp->{xli} - $dpsp->{fasx6}));
    }
  else {
    my $xomi = $self->{argumentofperigee} +
	$dpsp->{omgdt} * $dpsp->{atime};
    my $x2omi = $xomi + $xomi;
    my $x2li = $dpsp->{xli} + $dpsp->{xli};
    $xndot = $dpsp->{d2201} * sin ($x2omi + $dpsp->{xli} - DS_G22) +
	$dpsp->{d2211} * sin ($dpsp->{xli} - DS_G22) +
	$dpsp->{d3210} * sin ($xomi + $dpsp->{xli} - DS_G32) +
	$dpsp->{d3222} * sin ( - $xomi + $dpsp->{xli} - DS_G32) +
	$dpsp->{d4410} * sin ($x2omi + $x2li - DS_G44) +
	$dpsp->{d4422} * sin ($x2li - DS_G44) +
	$dpsp->{d5220} * sin ($xomi + $dpsp->{xli} - DS_G52) +
	$dpsp->{d5232} * sin ( - $xomi + $dpsp->{xli} - DS_G52) +
	$dpsp->{d5421} * sin ($xomi + $x2li - DS_G54) +
	$dpsp->{d5433} * sin ( - $xomi + $x2li - DS_G54);
    $xnddt = $dpsp->{d2201} * cos ($x2omi + $dpsp->{xli} - DS_G22) +
	$dpsp->{d2211} * cos ($dpsp->{xli} - DS_G22) +
	$dpsp->{d3210} * cos ($xomi + $dpsp->{xli} - DS_G32) +
	$dpsp->{d3222} * cos ( - $xomi + $dpsp->{xli} - DS_G32) +
	$dpsp->{d5220} * cos ($xomi + $dpsp->{xli} - DS_G52) +
	$dpsp->{d5232} * cos ( - $xomi + $dpsp->{xli} - DS_G52) +
	2 * ($dpsp->{d4410} * cos ($x2omi + $x2li - DS_G44) +
	$dpsp->{d4422} * cos ($x2li - DS_G44) +
	$dpsp->{d5421} * cos ($xomi + $x2li - DS_G54) +
	$dpsp->{d5433} * cos ( - $xomi + $x2li - DS_G54));
    }
my $xldot = $dpsp->{xni} + $dpsp->{xfact};
$xnddt = $xnddt * $xldot;


#C
#C INTEGRATOR
#C

@_ and do {
    my $delt = shift;
    $dpsp->{xli} = $dpsp->{xli} + $xldot * $delt + $xndot * $dpsp->{step2};
    $dpsp->{xni} = $dpsp->{xni} + $xndot * $delt + $xnddt * $dpsp->{step2};
    $dpsp->{atime} = $dpsp->{atime} + $delt;
    };

return ($xldot, $xndot, $xnddt);
}


#	_dpper

#	Calculate solar/lunar periodics.

#	Note that T must also be passed.

#	Note also that EM, XINC, OMGASM, XNODES, and XLL must be passed
#	by reference, since they get modified. Sigh.

sub _dpper {
my $self = shift;
my $dpsp = $self->{&TLE_INIT}{TLE_deep};
my ($em, $xinc, $omgasm, $xnodes, $xll, $t) = @_;
my @orig = map {defined $_ ? $_ : 'undef'}
	map {ref $_ eq 'SCALAR' ? $$_ : $_} @_
    if $self->{debug};

#C
#C ENTRANCES FOR LUNAR-SOLAR PERIODICS
#C
#C
#ENTRY DPPER(EM,XINC,OMGASM,XNODES,XLL)

my $sinis = sin ($$xinc);
my $cosis = cos ($$xinc);

# The following is an optimization that
# skips a bunch of calculations if the
# current time is within 30 (minutes) of
# the previous.
# This is the only reference to line 210

unless (defined $dpsp->{savtsn} && abs ($dpsp->{savtsn} - $t) < 30) {
    $dpsp->{savtsn} = $t;
    my $zm = $dpsp->{zmos} + DS_ZNS * $t;
    my $zf = $zm + 2 * DS_ZES * sin ($zm);
    my $sinzf = sin ($zf);
    my $f2 = .5 * $sinzf * $sinzf - .25;
    my $f3 = - .5 * $sinzf * cos ($zf);
    my $ses = $dpsp->{se2} * $f2 + $dpsp->{se3} * $f3;
    my $sis = $dpsp->{si2} * $f2 + $dpsp->{si3} * $f3;
    my $sls = $dpsp->{sl2} * $f2 + $dpsp->{sl3} * $f3 + $dpsp->{sl4} * $sinzf;
    $dpsp->{sghs} = $dpsp->{sgh2} * $f2 + $dpsp->{sgh3} * $f3 + $dpsp->{sgh4} * $sinzf;
    $dpsp->{shs} = $dpsp->{sh2} * $f2 + $dpsp->{sh3} * $f3;
    $zm = $dpsp->{zmol} + DS_ZNL * $t;
    $zf = $zm + 2 * DS_ZEL * sin ($zm);
    $sinzf = sin ($zf);
    $f2 = .5 * $sinzf * $sinzf - .25;
    $f3 = - .5 * $sinzf * cos ($zf);
    my $sel = $dpsp->{ee2} * $f2 + $dpsp->{e3} * $f3;
    my $sil = $dpsp->{xi2} * $f2 + $dpsp->{xi3} * $f3;
    my $sll = $dpsp->{xl2} * $f2 + $dpsp->{xl3} * $f3 + $dpsp->{xl4} * $sinzf;
    $dpsp->{sghl} = $dpsp->{xgh2} * $f2 + $dpsp->{xgh3} * $f3 + $dpsp->{xgh4} * $sinzf;
    $dpsp->{shl} = $dpsp->{xh2} * $f2 + $dpsp->{xh3} * $f3;
    $dpsp->{pe} = $ses + $sel;
    $dpsp->{pinc} = $sis + $sil;
    $dpsp->{pl} = $sls + $sll;
    }

my $pgh = $dpsp->{sghs} + $dpsp->{sghl};
my $ph = $dpsp->{shs} + $dpsp->{shl};
$$xinc = $$xinc + $dpsp->{pinc};
$$em = $$em + $dpsp->{pe};

if ($self->{inclination} >= .2) {

#C
#C APPLY PERIODICS DIRECTLY
#C
#218:

    my $ph = $ph / $dpsp->{siniq};
    my $pgh = $pgh - $dpsp->{cosiq} * $ph;
    $$omgasm = $$omgasm + $pgh;
    $$xnodes = $$xnodes + $ph;
    $$xll = $$xll + $dpsp->{pl};
    }
  else {

#C
#C APPLY PERIODICS WITH LYDDANE MODIFICATION
#C
#220:
    my $sinok = sin ($$xnodes);
    my $cosok = cos ($$xnodes);
    my $alfdp = $sinis * $sinok;
    my $betdp = $sinis * $cosok;
    my $dalf = $ph * $cosok + $dpsp->{pinc} * $cosis * $sinok;
    my $dbet = - $ph * $sinok + $dpsp->{pinc} * $cosis * $cosok;
    $alfdp = $alfdp + $dalf;
    $betdp = $betdp + $dbet;
    my $xls = $$xll + $$omgasm + $cosis * $$xnodes;
    my $dls = $dpsp->{pl} + $pgh - $dpsp->{pinc} * $$xnodes * $sinis;
    $xls = $xls + $dls;
    $$xnodes = _actan ($alfdp,$betdp);
    $$xll = $$xll + $dpsp->{pl};
    $$omgasm = $xls - $$xll - cos ($$xinc) * $$xnodes;
    }

$self->{debug} and print <<eod;
Debug _dpper -
    em     : $orig[0] -> $$em
    xinc   : $orig[1] -> $$xinc
    omgasm : $orig[2] -> $$omgasm
    xnodes : $orig[3] -> $$xnodes
    xll    : $orig[4] -> $$xll
    t      : $t
eod

return;
}


#######################################################################

#	_actan

#	This function wraps the atan2 function, and normalizes the
#	result to the range 0 < result < 2 * pi.

sub _actan {
my $rslt = atan2 ($_[0], $_[1]);
$rslt < 0 and $rslt += SGP_TWOPI;
$rslt;
}

#	_convert_out

#	Convert model results to kilometers and kilometers per second.

sub _convert_out {
my $self = shift;
$_[0] *= (SGP_XKMPER / SGP_AE);		# x
$_[1] *= (SGP_XKMPER / SGP_AE);		# y
$_[2] *= (SGP_XKMPER / SGP_AE);		# z
$_[3] *= (SGP_XKMPER / SGP_AE * SGP_XMNPDA / 86400);	# dx/dt
$_[4] *= (SGP_XKMPER / SGP_AE * SGP_XMNPDA / 86400);	# dy/dt
$_[5] *= (SGP_XKMPER / SGP_AE * SGP_XMNPDA / 86400);	# dz/dt
$self->universal (pop @_);
$self->eci (@_);

## $self->set (equinox_dynamical => $self->get ('epoch_dynamical'));
## $self->set (equinox_dynamical => $self->{epoch_dynamical});
$self->equinox_dynamical ($self->{epoch_dynamical});

$self;
}

# *equinox_dynamical = \&Astro::Coord::ECI::equinox_dynamical;

#	_set_illum

#	Setting the {illum} attribute is complex enough that the code
#	got pulled out into its own subroutine. As with all mutators,
#	the arguments are the object reference, the attribute name, and
#	the new value.

__PACKAGE__->alias (sun => 'Astro::Coord::ECI::Sun');
__PACKAGE__->alias (moon => 'Astro::Coord::ECI::Moon');
sub _set_illum {
    my $body = $_[2];
    unless (ref $body) {
	$type_map{$body} and $body = $type_map{$body};
	load_module ($body);
    }
    UNIVERSAL::isa ($body, 'Astro::Coord::ECI') or croak <<eod;
Error - The illuminating body must be an Astro::Coord::ECI, or a
        subclass thereof, or the words 'sun' or 'moon', which are
	handled as special cases. You tried to use a
	'@{[ref $body || $body]}'.
eod
    ref $body or $body = $body->new ();
    $_[0]->{$_[1]} = $body;
}

#######################################################################

#	Initialization

%status = (	# As of 21-Feb-2007, from Kelso's document dated 19-Feb-2007
          '25432' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 76',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25432
                     },
          '25106' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 47',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25106
                     },
          '24925' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Dummy mass 1',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24925
                     },
          '24948' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 28',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24948
                     },
          '24870' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 17',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24870
                     },
          '27451' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 98',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27451
                     },
          '25530' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 84',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25530
                     },
          '25273' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 57',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25273
                     },
          '24792' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 8',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24792
                     },
          '24793' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 7',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24793
                     },
          '25105' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 24',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25105
                     },
          '24966' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 35',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24966
                     },
          '25527' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 2',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25527
                     },
          '24965' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 19',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24965
                     },
          '25344' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 73',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25344
                     },
          '25276' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 60',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25276
                     },
          '24841' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 16',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24841
                     },
          '24950' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 31',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24950
                     },
          '25288' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 65',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25288
                     },
          '25531' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 83',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25531
                     },
          '25169' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 52',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25169
                     },
          '24869' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 15',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24869
                     },
          '25319' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 69',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25319
                     },
          '24872' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 18',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24872
                     },
          '25320' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 71',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25320
                     },
          '25263' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 61',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25263
                     },
          '25467' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 82',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25467
                     },
          '25262' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 51',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25262
                     },
          '25342' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 70',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25342
                     },
          '25170' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 56',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25170
                     },
          '25172' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 50',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25172
                     },
          '24871' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 920',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24871
                     },
          '25778' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 21',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25778
                     },
          '25291' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 68',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25291
                     },
          '25468' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 81',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25468
                     },
          '27376' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 96',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27376
                     },
          '24969' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 34',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24969
                     },
          '25272' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 55',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25272
                     },
          '25431' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 3',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25431
                     },
          '25287' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 64',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25287
                     },
          '25578' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 11',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25578
                     },
          '24949' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 30',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24949
                     },
          '27450' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 97',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27450
                     },
          '25077' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 42',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25077
                     },
          '25343' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 72',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25343
                     },
          '24926' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Dummy mass 2',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24926
                     },
          '25042' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 39',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25042
                     },
          '27374' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 94',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27374
                     },
          '25471' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 77',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25471
                     },
          '25078' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 44',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25078
                     },
          '25041' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 40',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25041
                     },
          '24842' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 911',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24842
                     },
          '24904' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 25',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24904
                     },
          '24907' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 22',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24907
                     },
          '25289' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 66',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25289
                     },
          '25108' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 49',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25108
                     },
          '24906' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 23',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24906
                     },
          '24836' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 914',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24836
                     },
          '25286' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 63',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25286
                     },
          '25528' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 86',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25528
                     },
          '24795' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 5',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24795
                     },
          '24839' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 10',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24839
                     },
          '27375' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 95',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27375
                     },
          '24837' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 12',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24837
                     },
          '24796' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 4',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24796
                     },
          '24905' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 46',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24905
                     },
          '27373' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 90',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27373
                     },
          '25275' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 59',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25275
                     },
          '24873' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 921',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24873
                     },
          '24903' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 26',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24903
                     },
          '24794' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 6',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24794
                     },
          '25290' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 67',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25290
                     },
          '25577' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 20',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25577
                     },
          '27372' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 91',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 27372
                     },
          '24945' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 32',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24945
                     },
          '25274' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 58',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25274
                     },
          '25040' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 41',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25040
                     },
          '25777' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 14',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25777
                     },
          '24946' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 33',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24946
                     },
          '25469' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 80',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25469
                     },
          '25173' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 53',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25173
                     },
          '24967' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 36',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24967
                     },
          '25171' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 54',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25171
                     },
          '24968' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 37',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24968
                     },
          '25039' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 43',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25039
                     },
          '25043' => {
                       'comment' => '',
                       'status' => 2,
                       'name' => 'Iridium 38',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25043
                     },
          '24840' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 13',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24840
                     },
          '24944' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 29',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 24944
                     },
          '25345' => {
                       'comment' => '',
                       'status' => 1,
                       'name' => 'Iridium 74',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25345
                     },
          '25285' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 62',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25285
                     },
          '25104' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 45',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25104
                     },
          '25346' => {
                       'comment' => '',
                       'status' => 0,
                       'name' => 'Iridium 75',
                       'class' => 'Astro::Coord::ECI::TLE::Iridium',
                       'type' => 'iridium',
                       'id' => 25346
                     },
	);

1;

__END__

=back

=head2 Attributes

This class has the following additional public attributes. The
description gives the data type. It may also give one of the following
if applicable:

parse - if the attribute is set by the parse() method;

read-only - if the attribute is read-only;

static - if the attribute may be set on the class as well as an object.

Note that the orbital elements provided by NORAD are tweaked for use by
the models implemented by this class. If you plug them in to the
same-named parameters of other models, your mileage may vary
significantly.

=over

=item appulse (numeric, static)

This attribute contains the angle of the widest appulse to be reported
by the pass() method, in radians.

The default is equivalent to 10 degrees.

=item argumentofperigee (numeric, parse)

This attribute contains the argument of perigee (angular distance from
ascending node to perigee) of the orbit, in radians.

=item backdate (boolean, static)

This attribute determines whether the pass() method will go back before
the epoch of the data. If false, the pass() method will silently adjust
its start time forward. If this places the start time after the end
time, an empty list is returned.

B<Note> that this is a change from the behavior of
Astro::Coord::ECI::TLE version 0.010, which threw an exception if the
backdate adjustment placed the start time after the end time.

The default is 1 (i.e. true).

=item bstardrag (numeric, parse)

This attribute contains the B* drag term, decoded into a number.

=item classification (string, parse)

This attribute contains the security classification. You should
expect to see only the value 'U', for 'Unclassified.'

=item ds50 (numeric, readonly, parse)

This attribute contains the L<epoch|/item_epoch>, in days since 1950.
Setting the L<epoch|/item_epoch> also modifies this attribute.

=item eccentricity (numeric, parse)

This attribute contains the orbital eccentricity, with the
implied decimal point inserted.

=item elementnumber (numeric, parse)

This attribute contains the element set number of the data set. In
theory, this gets incremented every time a data set is issued.

=item ephemeristype (numeric, parse)

This attribute records a field in the data set which is supposed to
specify which model to use with this data. In practice, it seems
always to be zero.

=item epoch (numeric, parse)

This attribute contains the epoch of the orbital elements - that is,
the 'as-of' date and time - as a Perl date. Setting this attribute
also modifies the epoch_dynamical and ds50 attributes.

=item epoch_dynamical (numeric, readonly, parse)

This attribute contains the dynamical time corresponding to the
L<epoch|/item_epoch>. Setting the L<epoch|/item_epoch> also modifies
this attribute.

=item firstderivative (numeric, parse)

This attribute contains the first time derivative of the mean
motion, in radians per minute squared.

=item geometric (boolean, static)

Tells the pass() method whether to calculate rise and set relative
to the geometric horizon (if true) or the horizon attribute (if
false)

The default is 0 (i.e. false).

=item id (numeric, parse)

This attribute contains the NORAD SATCAT catalog ID.

=item illum (string, static)

This attribute specifies the source of illumination for the body.  You
may specify the class name 'Astro::Coord::ECI' or the name of any
subclass (though in practice only 'Astro::Coord::ECI::Sun' or
'Astro::Coord::ECI::Moon' will do anything useful), or an alias()
thereof, or you may specify an object of the appropriate class. When you
access this attribute, you get an object.

In addition to the full class names, 'sun' and 'moon' are set up as
aliases for Astro::Coord::ECI::Sun and Astro::Coord::ECI::Moon
respectively. Other aliases can be set up using the alias() mechanism.
The value 'sun' (or something equivalent) is probably the only useful
value, but I know people have looked into Iridium 'Moon flares', so I
exposed the attribute.

The default is 'sun'.

=item interval (numeric, static)

If positive, this attribute specifies that the pass() method return
positions at this interval (in seconds) across the sky. The associated
event code of these will be PASS_EVENT_NONE. If zero or negative, pass()
will only return times when some event of interest occurs.

The default is 0.

=item inclination (numeric, parse)

This attribute contains the orbital inclination in radians.

=item international (string, parse)

This attribute contains the international launch designator.
This consists of three parts: a two-digit number (with leading zero if
needed) giving the last two digits of the launch year (in the range
1957-2056); a three-digit number (with leading zeros if needed) giving
the order of the launch within the year, and one to three letters
designating the "part" of the launch, with payload(s) getting the
first letters, and spent boosters, debris, etc getting the rest.

=item limb (boolean, static)

This attribute tells the pass() method how to compute illumination
of the body. If true, it is computed based on the upper limb of the
source of illumination; if false, it is based on the center.

The default is 1 (i.e. true).

=item meananomaly (numeric, parse)

This attribute contains the mean orbital anomaly at the epoch, in
radians. In slightly less technical terms, this is the angular
distance a body in a circular orbit of the same period (that is
what the 'mean' means) would be from perigee at the epoch, measured
in the plane of the orbit.

=item meanmotion (numeric, parse)

This attribute contains the mean motion of the body, in radians per
minute.

=item model (string, static)

This attribute contains the name of the model to be run (i.e. the name
of the method to be called) when the time_set() method is called, or a
false value if no model is to be run. Legal model names are: model,
model4, model8, null, sgp, sgp4, sgp8, sdp4, and sdp8.

The default is 'model'. Setting the value on the class changes the
default.

=item name (string, parse (three-line sets only))

This attribute contains the common name of the body.

=item reblessable (boolean)

This attribute says whether the rebless() method is allowed to rebless
this object. If false, the object will not be reblessed when its
id changes.

Note that if this attribute is false, setting it true will cause the
object to be reblessed.

The default is true (i.e. 1).

=item revolutionsatepoch (numeric, parse)

This attribute contains number of revolutions the body has made since
launch, at the epoch.

=item rightascension (numeric, parse)

This attribute contains the right ascension of the ascending node
of the orbit at the epoch, in radians.

=item secondderivative (numeric, parse)

This attribute contains the second time derivative of the mean
motion, in radians per minute cubed.

=item tle (string, readonly, parse)

This attribute contains the input data used by the parse() method to
generate this object. If the object was not created by the parse()
method, this attribute will be empty.

=item visible (boolean, static)

This attribute tells the pass() method whether to report only passes
which are illuminated (if true) or all passes (if false).

The default is 1 (i.e. true).

=back

=head1 ACKNOWLEDGMENTS

The author wishes to acknowledge the following individuals.

Dominik Brodowski (L<http://www.brodo.de/>), whose SGP C-lib
(available at L<http://www.brodo.de/space/sgp/>) provided a
reference implementation that I could easily run, and pick
apart to help get my own code working. Dominik based his work
on Dr. Kelso's Pascal implementation.

Felix R. Hoots and Ronald L. Roehric, the authors of "SPACETRACK
REPORT NO. 3 - Models for Propagation of NORAD Element Sets,"
which provided the basis for the Astro::Coord::ECI::TLE module.

Dr. T. S. Kelso, who compiled this report and made it available at
L<http://celestrak.com/NORAD/documentation/spacetrk.pdf>. Dr. Kelso's
Two-Line Element Set Format FAQ
(L<http://celestrak.com/columns/v04n03/>) was also extremely helpful,
as was his discussion of the coordinate system used
(L<http://celestrak.com/columns/v02n01/>) and (indirectly) his Pascal
implementation of these models.

=head1 SEE ALSO

I am aware of no other modules that perform calculations with NORAD
orbital element sets. The Astro-Coords package by Tim Jenness
provides calculations using orbital elements, but the NORAD elements
are tweaked for use by the models implemented in this package.

=head1 AUTHOR

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2005, 2006, 2007 by Thomas R. Wyant, III
(F<wyant at cpan dot org>). All rights reserved.

=head1 LICENSE

This module is free software; you can use it, redistribute it
and/or modify it under the same terms as Perl itself. Please see
L<http://perldoc.perl.org/index-licence.html> for the current licenses.

This software is provided without any warranty of any kind, express or
implied. The author will not be liable for any damages of any sort
relating in any way to this software.

=cut
