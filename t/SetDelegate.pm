package t::SetDelegate;

use strict;
use warnings;

use base qw{Astro::Coord::ECI::TLE};

our $VERSION = '0.003';

sub new {
    my ($class, @args) = @_;
    $class = ref $class if ref $class;
    my $self = $class->SUPER::new ();
    $self->set (model => 'null', @args);
    return $self;
}

*_nodelegate_nodelegate = \&nodelegate;
sub nodelegate {return $_[0]}

sub delegate {return $_[0]}

sub rebless {}	# No-op rebless() to defeat class changes.

1;

