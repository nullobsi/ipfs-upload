package IpfsUpload::Util;
use strict;
use warnings FATAL => 'all';
use experimental qw/signatures/;

use Mojo::JSON qw/decode_json encode_json/;
use Time::Piece;

use Crypt::Argon2 qw/argon2id_pass argon2id_verify/;
use Bytes::Random::Secure qw/random_bytes_hex/;

sub add_pass($pass) {
	my $salt = random_bytes_hex(16);
	my $encoded = argon2id_pass($pass, $salt, 3, '32M', 1, 16);
	return $encoded;
}

sub check_pass($pass, $hash) {
	return argon2id_verify($hash, $pass);
}

sub date_format($date) {
	$date =~ s/ /T/;
	$date =~ s/(\d\d)$/$1:00/;
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

sub update_query($c, $query) {
	my $cid = $c->param('cid');
	my $name = $c->param('name');
	# TODO: Text matching strategy
	my $match = $c->param('match');

	# TODO: filter by status (only pinned)
	my $status = $c->param('status');

	my $before = $c->param('before');
	my $after = $c->param('after');


	# Only app_name is supported.
	my $meta = $c->param('meta');
	my $app_name;

	if (defined $meta) {
		eval {
			$meta = decode_json $meta;
			$app_name = $meta->{app_name};
		};

		if ($@) {
			$c->render(status => 400, openapi =>{
				error => {
					reason  => "INVALID_PARAM",
					details => "Parameter 'meta' is invalid.",
				},
			});

			return 0;
		}

	}

	# Not supporting meta.

	if (defined $cid) {
		$query->{cid} = $cid;
	}
	if (defined $name) {
		$query->{name} = $name;
	}
	if (defined $before) {
		$query->{created_at} = { '<' => $before };
	}
	if (defined $after) {
		if (defined $query->{created_at}) {
			$query->{created_at}->{'>'} = $after;
		} else {
			$query->{created_at} = { '>' => $after };
		}
	}
	if (defined $app_name) {
		$query->{app_name} = $app_name;
	}

	return 1;
}

1;
