package IpfsUpload::Model::Pins;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base -base, -signatures;

has 'sql';

sub add($self, $pin) {
	return $self->sql->db->insert_p('pins', $pin, {returning => ['id', 'created_at', 'cid']})->then(sub ($res) {
		return $res->hash;
	});
}

sub del($self, $where) {
	return $self->sql->db->delete_p('pins', $where);
}

sub get($self, $where) {
	return $self->sql->db->select_p('pins', '*', $where, {limit => 1})->then(sub ($res) {
		return $res->hash;
	});
}

sub exists($self, $where) {
	return $self->sql->db->select_p('pins', 'id', $where, {limit => 1})->then(sub ($res) {
		return $res->rows == 1;
	});
}

sub update($self, $update, $where) {
	return $self->sql->db->update_p('pins', $update, $where, { returning => ['cid', 'id']})->then(sub ($res) {
		return $res->hash;
	});
}

sub cid_count($self, $cid) {
	return $self->count({cid => $cid});
}

sub count($self, $where) {
	return $self->sql->db->select_p('pins', 'count(*) as count', $where)->then(sub ($res) {
		return $res->hash->{count};
	});
}

sub list($self, $where, $limit) {
	return $self->sql->db->select_p('pins', '*', $where, {order_by => {-desc => 'created_at'}, limit => $limit})->then(sub ($res) {
		return $res->hashes;
	});
}

1;
