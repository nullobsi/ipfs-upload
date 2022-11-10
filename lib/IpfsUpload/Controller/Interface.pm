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

sub token_list($c) {
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}

	return $c->users->list_tokens($uid)->then(sub ($tokens) {
		$c->stash(tokens => $tokens);
		$c->render('interface/tokens');
	})
}

sub gen_token_post($c) {
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}

	my $v = $c->validation;
	return $c->render('interface/generateToken') unless $v->has_data;

	$v->required('app_name', 'trim')->size(1,64);
	return $c->render('interface/generateToken') if $v->has_error;

	my $app_name = $v->param('app_name');

	return $c->users->gen_token($uid, $app_name)->then(sub ($res) {
		$c->flash(msg => "Your new token is: $res");
		return $c->redirect_to('/my/tokens');
	});
}

sub gen_token_get($c) {
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}

	return $c->render('interface/generateToken');
}

sub del_token($c) {
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}

	return $c->users->del_token($uid, $c->param('id'))->then(sub {
		$c->flash(msg => 'Token deleted.');
		return $c->redirect_to('/my/tokens')
	});
}

1;
