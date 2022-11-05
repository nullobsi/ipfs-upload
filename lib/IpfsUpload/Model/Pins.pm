package IpfsUpload::Model::Pins;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base -base, -signatures;

has 'pg';

sub add($self, $pin) {
	return $self->pg->db->insert_p('pins', $pin, {returning => 'id'})->then(sub ($res) {
		return $res->hash->{id};
	});
}

sub list($self, $where, $limit) {
	return $self->pg->db->select_p('pins', '*', $where, {order_by => {-desc => 'created_at'}, limit => $limit})->then(sub ($res) {
		return $res->hashes;
	});
}

1;
