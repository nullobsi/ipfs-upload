package IpfsUpload::Controller::Interface;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub landing($c) {
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}

	my $gateway = $c->config->{ipfs}->{gatewayPubUrl};

	my $limit = $c->param('limit') || 10;
	my $before = $c->param('before');

	my %query = (
		uid => $uid,
	);

	if (defined $before) {
		$query{created_at} = { '<' => $before };
	}

	$c->pins->list(\%query, $limit)->then(sub ($res) {
		$c->stash(
			pins    => $res,
			limit   => $limit,
			gateway => $gateway,
		);

		if (@$res == $limit) {
			$c->stash(nextPage => $res->[-1]->{created_at});
		} else {
			$c->stash(nextPage => 0);
		}

		$c->render('interface/landingPage');
	})
}

1;
