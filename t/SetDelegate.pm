package t::SetDelegate;

use strict;
use warnings;

use base qw{Astro::Coord::ECI::TLE};

our $VERSION = '0.001_01';

sub new {
my $class = shift;
$class = ref $class if ref $class;
my $self = $class->SUPER::new ();
$self->set (model => 'null', @_);
$self;
}

*_nodelegate_nodelegate = \&nodelegate;
sub nodelegate {$_[0]};

sub delegate {$_[0]};

sub rebless {}	# No-op rebless() to defeat class changes.

1;

