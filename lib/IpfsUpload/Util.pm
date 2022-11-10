package IpfsUpload::Util;
use strict;
use warnings FATAL => 'all';
use experimental qw/signatures/;

use Time::Piece;


sub date_format($date) {
	print "$date\n";
	$date =~ s/ /T/;
	$date =~ s/(\d\d)$/$1:00/;
	print "$date\n";
	return $date;
}

sub check_auth($c) {
	my $auth = $c->req->headers->authorization;
	if (defined $auth) {
		$auth =~ s/Bearer //;
		my $tinfo = $c->users->token_info($auth);
		if (defined $tinfo) {
			$c->stash(
				uid => $tinfo->{uid},
				app_name => $tinfo->{app_name}
			);
			return 1;
		}
	}

	# Try session auth
	my $uid = $c->session->{uid};
	if (defined $uid) {
		$c->stash(
			uid      => $uid,
			app_name => 'WebInterface',
		);
		return 1;
	}

	return 0;
}

1;
