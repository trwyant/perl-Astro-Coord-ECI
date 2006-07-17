package t::Ctags;

our $VERSION = '0.001';

use ExtUtils::MakeMaker;

sub make_tags {
    my $fh;
    open ($fh, '<', 'MANIFEST') or die <<eod;
Error - Failed to open MANIFEST.
        $!
eod
    my @files;
    while (<$fh>) {
	chomp;
	s/\s+.*//;
	m/\.pm$/i || m|bin/|i or next;
	push @files, $_;
    }
    system ("ctags @files");
    $? and die <<eod;
Error - ctags command failed. Status = $?
eod

    my @tags;
    open ($fh, '<', 'tags') or die <<eod;
Error - Failed to open tags for input.
        $!
eod
    while (<$fh>) {push @tags, $_}
    foreach my $fn (@files) {
	my $version = MM->parse_version ($fn);
	next unless defined $version && $version ne 'undef';
	push @tags, "\$VERSION\t$fn\t" . '/\m^\s*our\s\s*\$VERSION\s*=/;"' .
		"\tv\n";
    }
    open ($fh, '>', 'tags') or die <<eod;
Error - Failed to open tags for output.
        $!
eod
    foreach (sort @tags) {print $fh $_}
}

package MY;

my $ctags = `which ctags`;

sub top_targets {
    my $self = shift;
    my $target = $self->SUPER::top_targets (@_);
    if ($ctags) {
	$target =~ s/$/ tags/m;
	$target .= <<'eod';

tags :: $(MAN1PODS) $(MAN3PODS)
	perl -Mt::Ctags -e 't::Ctags->make_tags'

eod
    }
    $target;
}

1;
