package main;

use strict;
use warnings;

use lib qw{ inc };

use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::TLE::Set;
use Astro::Coord::ECI::SetDelegate;
use Astro::Coord::ECI::Utils qw{ :time };
use Test;

plan tests => 53, todo => [];

my $test = 0;
my $success;

{	# Begin local symbol block.
    my $set = eval {Astro::Coord::ECI::TLE::Set->new ()};
    $test++;
    print <<eod;
#
# Test $test - Instantiate a set.
eod
    print "    Error: $@\n" if $@;
    ok ($set);
    my $skip = $set ? '' : 'Failed to instantiate set.';

    foreach ([first => 2, 6, 2006], [second => 4, 6, 2006]) {
	my $which = shift @$_;
	$success = $skip ? undef : eval {
	    $set->add(dummy( timegm( 0, 0, 0, @$_ ), 99999,
		    'Anonymous' ) );
	    1;
	};
	$test++;
	print <<eod;
#
# Test $test - Add $which member.
eod
	print "    Error: $@\n" if $@;
	skip( $skip, $success );
    }


    foreach ([before => 1, 6, 2006, 2, 6, 2006],
	    [first => 2, 6, 2006, 2, 6, 2006],
	    [between => 3, 6, 2006, 2, 6, 2006],
	    [last => 4, 6, 2006, 4, 6, 2006],
	    [after => 5, 6, 2006, 4, 6, 2006],
	    ) {
	my $what = shift @$_;
	my $time = timegm (0, 0, 0, splice @$_, 0, 3);
	my $expect = timegm (0, 0, 0, @$_);
	$test++;
	my $got;
	$skip or $got = eval {$set->select ($time)->get ('epoch')};
	print <<eod;
#
# Test $test - Select $what set members.
#      Time: @{[scalar gmtime $time]} GMT
#    Expect: @{[scalar gmtime $expect]} GMT
eod
	print $skip ? <<eod : $@ ? <<eod : <<eod;
#   Skipped
eod
#     Error: $@
eod
#       Got: @{[scalar gmtime $got]} GMT
eod
	$got ||= 0;
	skip ($skip, $expect == $got);
    }

    foreach ([before => 1, 6, 2006, 2, 6, 2006],
	    [first => 2, 6, 2006, 2, 6, 2006],
	    [between => 3, 6, 2006, 2, 6, 2006],
	    [last => 4, 6, 2006, 4, 6, 2006],
	    [after => 5, 6, 2006, 4, 6, 2006],
	    ) {
	my $what = shift @$_;
	my $time = timegm (0, 0, 0, splice @$_, 0, 3);
	my $expect = timegm (0, 0, 0, @$_);
	$test++;
	my ($tle, $got);
	$skip or $tle = eval {$set->universal ($time)};
	$tle and $got = eval {$tle->get ('epoch')};
	$success = $tle && $got;
	print <<eod;
#
# Test $test - Set universal() $what set members - resultant epoch.
#      Time: @{[scalar gmtime $time]} GMT
#    Expect: @{[scalar gmtime $expect]} GMT
eod
	print $skip ? <<eod : $success ? <<eod : <<eod;
#   Skipped
eod
#       Got: @{[scalar gmtime $got]} GMT
eod
#     Error: $@
eod
	$got ||= 0;
	skip ($skip, $expect == $got);

	$test++;
	$got = $tle ? (eval {$tle->universal()} || 0) : 0;
	print <<eod;
#
# Test $test - Set universal() $what set members - resultant member's time.
#    Expect: @{[scalar gmtime $time]} GMT
eod
	print $skip ? <<eod : $@ ? <<eod : <<eod;
#   Skipped
eod
#  Error: $@
eod
#       Got: @{[scalar gmtime $got]} GMT
eod
	skip ($skip, $time == $got);

	$test++;
	$got = eval {$set->universal ()} unless $skip;
	$got ||= 0;
	print <<eod;
#
# Test $test - Set universal() $what set members - time returned by set object.
#    Expect: @{[scalar gmtime $time]} GMT
eod
	print $skip ? <<eod : $@ ? <<eod : <<eod;
#   Skipped
eod
#  Error: $@
eod
#       Got: @{[scalar gmtime $got]} GMT
eod
	skip ($skip, $time == $got);
    }

    my @members;
    $skip or @members = $set->members();
    $test++;
    print <<eod;
#
# Test $test - \$set->members ();
#    Expected: 2
#         Got: @{[scalar @members]}
eod
    skip ($skip, @members == 2);

    $success = $skip ? undef : eval { $set->set_all (name => 'Nemo') };
    $test++;
    print <<eod;
#
# Test $test - \$set->set (name => 'Nemo')
#    Expected: no exception
#         Got: @{[ $success ? 'no exception' :
              ( $@ || 'unrecorded exception' ) ]}
eod
    skip ( $skip, $success );

    foreach ([0, 2, 6, 2006],
	    [1, 4, 6, 2006],
	) {
	my $inx = shift @$_;
	my $expect = timegm (0, 0, 0, splice @$_, 0, 3);
	my $got = $skip ? 0 : $members[$inx]->get ('epoch');
	$test++;
	print <<eod;
#
# Test $test - Epoch of member $inx
#    Expected: @{[scalar gmtime $expect]} GMT
#         Got: @{[scalar gmtime $got]} GMT
eod
	skip ($skip, $expect == $got);

	$test++;
	$got = $skip ? '' : $members[$inx]->get ('name');
	print <<eod;
#
# Test $test - Effect of \$set->set ('Nemo') on member $inx
#    Expected: 'Nemo'
#         Got: '$got'
eod
	skip ($skip, $got eq 'Nemo');
    }

    $set->clear () unless $skip;
    $test++;
    my $got = $skip ? 0 : $set->members ();
    print <<eod;
#
# Test $test - \$set->clear ()
#    Expected: 0
#         Got: $got
eod
    skip ($skip, $got == 0);


}	# End of local symbol block.

foreach my $single (0, 1) {

    local $Astro::Coord::ECI::TLE::Set::Singleton = $single;

    my @set = eval {Astro::Coord::ECI::TLE::Set->aggregate (
		dummy (timegm (0, 0, 0, 1, 6, 106), 99999),
		dummy (timegm (0, 0, 0, 2, 6, 106)),
		dummy (timegm (0, 0, 0, 1, 6, 106), 11111),
		)};
    $test++;
    print <<eod;
#
# Test $test - Aggregate TLEs with Singleton = $single.
eod
    print "#  Error: $@\n" if $@;
    ok (!$@);
    my $skip = $@ ? 'Failed to create aggregate.' : '';

    $test++;
    print <<eod;
#
# Test $test - Number of objects generated by aggregate().
#  Expect: 2
#     Got: @{[scalar @set]}
eod
    skip ($skip, @set == 2);
    foreach ([0, $single ? 'Astro::Coord::ECI::TLE::Set' :
		'Astro::Coord::ECI::TLE'],
	    [1, 'Astro::Coord::ECI::TLE::Set'],
	    ) {
	my ($inx, $expect) = @$_;
	$test++;
	my $got = $skip ? '' : ref $set[$inx];
	print <<eod;
#
# Test $test - Class of \$set[$inx]
#  Expect: $expect
#     Got: $got
eod
	skip ($skip, $expect eq $got);
    }

}

{	# Begin local symbol block.

    my $set1 = Astro::Coord::ECI::TLE::Set->new (
	Astro::Coord::ECI::SetDelegate->new (
	    id => 99999,
	    name => 'Anonymous',
	    epoch => timegm (0, 0, 0, 1, 6, 106)
	));
    my $set2 = Astro::Coord::ECI::TLE::Set->new ();
    eval {	## no critic (RequireCheckingReturnValueOfEval)
	$set2->add( $set1 )
    };
    $test++;
    my $got = $set2->members();
    print <<eod;
#
# Test $test - Add a set to another set.
#    Expected: 1 member.
#         Got: $got member@{[$got == 1 ? '' : 's']}
eod
    ok ($got == 1);
}	# End local symbol block.

{	# Begin local symbol block.
    my $set = Astro::Coord::ECI::TLE::Set->new (
	Astro::Coord::ECI::SetDelegate->new (
	    id => 22222,
	    name => 'Anonymous',
	    epoch => timegm (0, 0, 0, 2, 6, 106)
	));
    my $skip = $set ? '' : 'Failed to instantiate set';
    foreach ([delegate => 'Astro::Coord::ECI::SetDelegate'],
	    [nodelegate => 'Astro::Coord::ECI::TLE::Set'],
	    ) {
	my ($method, $expect) = @$_;
	my $got = $set ? ref $set->$method () : '';
	$test++;
	print <<eod;
#
# Test $test - Delegation - $method()
#    Expect: '$expect'
#       Got: '$got'
eod
	skip ($skip, $expect eq $got);
    }

}	# End of local symbol block.

{	# Begin local symbol block.
    my $set = Astro::Coord::ECI::TLE::Set->new ();
    my $status = 'empty';
    foreach ([members => 1], [delegate => 0],
	    [add => Astro::Coord::ECI::SetDelegate->new (
		id => 333333,
		name => 'Nobody',
		epoch => timegm (0, 0, 0, 2, 6, 106))],
	    [members => 1], [delegate => 1],
	    [clear => 0],
	    [members => 1], [delegate => 0],
	    ) {
	my ($method, $expect) = @$_;
	if ($method eq 'add') {
	    $set->add ($expect);
	    $status = 'non-empty';
	} elsif ($method eq 'clear') {
	    $set->clear ();
	    $status = 'empty';
	} else {
	    $test++;
	    my $got = $set->can ($method) ? 1 : 0;
	    print <<eod;
#
# Test $test - \$set->can ('$method') with \$set $status.
#    Expect: $expect
#       Got: $got
eod
	ok ($expect == $got);
	}
    }

}	# End of local symbol block.

{	# Begin local symbol block.
    my $set = Astro::Coord::ECI::TLE::Set->new ();
    my $members = 0;
    foreach ([represents => undef, 'Exception thrown'],
	    [represents => 'Astro::Coord::ECI', 'Exception thrown'],
	    [add => dummy (timegm (0, 0, 0, 6, 1, 106), 99999)],
	    [represents => undef, 'Astro::Coord::ECI::TLE'],
	    [represents => 'Astro::Coord::ECI', 1],
	    [represents => 'Astro::Coord::ECI::TLE', 1],
	    [represents => 'Astro::Coord::ECI::TLE::Set', 0],
	    ) {
	my ($method, @args) = @$_;
	if ($method eq 'represents') {
	    my ($arg, $want) = @args;
	    my $got = eval {$set->represents ($arg)};
	    $got = 'Exception thrown' if $@;
	    $test++;
	    print <<eod;
#
# Test $test - \$set->represents (@{[defined $arg ? "'$arg'" : 'undef']})
#   Members: $members
#    Expect: $want
#       Got: $got
eod
	    $want =~ m/\D/ ? ok ($want eq $got) : ok ($want == $got);
	} else {
	    $set->$method (@args);
	    $members = $set->members ();
	}
    }
}


########################################################################
#
#	$tle = dummy ($epoch, $id, $name);

#	Make a dummy Astro::Coord::ECI::TLE object. The $id and
#	$name default to the last one used. If none has been
#	specified, the defaults are 99999 and 'Anonymous'.

{	# Local symbol block.

    my ($id, $name);
    BEGIN {($id, $name) = (99999, 'Anonymous')};
    sub dummy {
	(my $epoch = shift) or die <<eod;
Error - You must specify the epoch.
eod
	$id = shift || $id;
	$name = shift || $name;
	return Astro::Coord::ECI::TLE->new (id => $id,
	    name => $name || 'Anonymous', epoch => $epoch, model => 'null');
    }
}	# End of local symbol block.

1;

# ex: set textwidth=72 :
