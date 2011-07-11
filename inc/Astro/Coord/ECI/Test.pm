package Astro::Coord::ECI::Test;

use 5.006002;

use strict;
use warnings;

use Carp;

our $VERSION = '0.040';

use base qw{ Exporter };

use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::Utils qw{ rad2deg };

our @EXPORT_OK = qw{ format_pass format_time };
our %EXPORT_TAGS = ( all => \@EXPORT_OK );


{

    my @decoder;

    # We jump through this hoop in case the constants turn out not to be
    # dualvars.
    BEGIN {
	$decoder[ PASS_EVENT_NONE ]	= '';
	$decoder[ PASS_EVENT_SHADOWED ]	= 'shdw';
	$decoder[ PASS_EVENT_LIT ]	= 'lit';
	$decoder[ PASS_EVENT_DAY ]	= 'day';
	$decoder[ PASS_EVENT_RISE ]	= 'rise';
	$decoder[ PASS_EVENT_MAX ]	= 'max';
	$decoder[ PASS_EVENT_SET ]	= 'set';
	$decoder[ PASS_EVENT_APPULSE ]	= 'apls';
	$decoder[ PASS_EVENT_START ]	= 'start';
	$decoder[ PASS_EVENT_END ]	= 'end';
    }

    sub _format_event {
	my ( $event ) = @_;
	defined $event or return '';
	return $decoder[ $event + 0 ];
    }

}

sub format_pass {
    my ( $pass ) = @_;
    my $rslt = '';
    $pass or return $rslt;
    foreach my $event ( @{ $pass->{events} } ) {
	$rslt .= sprintf '%19s %5s %5s %7s %-5s %-5s',
	    format_time( $event->{time} ),
	    _format_optional( '%5.1f', $event, 'elevation', \&rad2deg ),
	    _format_optional( '%5.1f', $event, 'azimuth', \&rad2deg ),
	    _format_optional( '%7.1f', $event, 'range' ),
	    _format_event( $event->{illumination} ),
	    _format_event( $event->{event} ),
	    ;
	$rslt =~ s/ \s+ \z //smx;
	$rslt .= "\n";
	if ( $event->{appulse} ) {
	    my $sta = $event->{station};
	    my ( $az, $el ) = $sta->azel(
		$event->{appulse}{body}->universal( $event->{time} ) );
	    $rslt .= sprintf '%19s %5.1f %5.1f %7.1f %s', '',
		rad2deg( $el ),
		rad2deg( $az ),
		rad2deg( $event->{appulse}{angle} ),
		$event->{appulse}{body}->get( 'name' ),
		;
	    $rslt =~ s/ \s+ \z //smx;
	    $rslt .= "\n";
	}
    }
    $rslt =~ s/ (?<= \s ) - (?= 0 [.] 0+ \s ) / /smxg;
    return $rslt;
}

sub _format_optional {
    my ( $tplt, $hash, $key, $xfrm ) = @_;
    defined( my $val = $hash->{$key} )
	or return '';
    'CODE' eq ref $xfrm
	and $val = $xfrm->( $val );
    return sprintf $tplt, $val;
}

sub format_time {
    my ( $time ) = @_;
    my @parts = gmtime int( $time + 0.5 );
    return sprintf '%04d/%02d/%02d %02d:%02d:%02d', $parts[5] + 1900,
	$parts[4] + 1, @parts[ 3, 2, 1, 0 ];
}


1;

__END__

=head1 NAME

Astro::Coord::ECI::Test - Useful subroutines for testing

=head1 SYNOPSIS

 use lib qw{ inc };
 use Astro::Coord::ECI::Test qw{ :all };
 
 say 'Time: ', format_time( time );

=head1 DESCRIPTION

This module is private to the Astro::Coord::ECI package. The author
reserves the right to change or revoke it without notice.

This module is a repository for subroutines used in testing
L<Astro::Coord::ECI|Astro::Coord::ECI>.


=head1 SUBROUTINES

The following public subroutines are exported by this module. None of
them are exported by default, but export tag C<:all> exports all of
them.

=head2 format_pass

 print format_pass( $pass );

This subroutine converts the given C<$pass> (which is a reference to one
of the hashes returned by the C<Astro::Coord::ECI::TLE> C<pass()>
method) to a string. The output contains the events of the pass one per
line, with date and time (ISO-8601-ish, GMT), azimuth, elevation and
range (or blanks if not present), illumination, and event name for each
pass.  For appulses the time, position, and name of the appulsed body
are also provided, on a line after the event.

=head2 format_time

 print format_time( $pass->{time} );

This subroutine converts a given Perl time into an ISO-8601-ish GMT
time. It is used by C<format_pass()>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
