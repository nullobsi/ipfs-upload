package IpfsUpload::Model::Users;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base -base, -signatures;

has 'pg';

sub token_info($self, $token) {
	return $self->pg->db->select('access_token', ['uid', 'app_name'], { token => $token })->hash;
}

sub token_info_p($self, $token) {
	return $self->pg->db->select_p('access_token', ['uid', 'app_name', 'id'], {
		token => $token,
	})->then(sub ($res) {
		return $res->hash;
	});
}

sub list_tokens($self, $uid) {
	return $self->pg->db->select_p('access_token', ['uid', 'app_name', 'id'], {
		uid => $uid,
	})->then(sub ($res) {
		return $res->hashes;
	});
}

sub getOrMake($self, $username) {
	return $self->pg->db->select_p('users', ['uid'], {username => $username})->then(sub ($res) {
		if ($res->rows != 0) {
			return $res->hash->{uid};
		}
		return $self->pg->db->insert_p('users', {username => $username}, {returning => 'uid'})->then(sub ($n) {
			return $n->hash->{uid};
		});
	});
}

1;
