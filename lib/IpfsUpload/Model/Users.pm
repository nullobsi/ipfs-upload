package IpfsUpload::Model::Users;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base -base, -signatures;

has 'pg';

sub id_from_token($self, $token) {
	my $res = $self->pg->db->select('access_token', ['uid'], { token => $token })->hash;

	if (!defined $res) {
		return undef;
	}

	return $res->{uid};
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
