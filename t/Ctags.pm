package t::Ctags;

our $VERSION = '0.001';

package MY;

my $ctags = `which ctags`;

sub top_targets {
    my $self = shift;
    my $target = $self->SUPER::top_targets (@_);
    if ($ctags) {
	$target =~ s/$/ tags/m;
	$target .= <<eod;

tags :: \$(MAN1PODS) \$(MAN3PODS)
\tctags `grep .pm MANIFEST && grep bin/ MANIFEST`

eod
    }
    $target;
}

1;
