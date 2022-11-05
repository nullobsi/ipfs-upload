package IpfsUpload::Model::Users;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base -base, -signatures;

has 'pg';

sub id($self, $token) {
	my $res = $self->pg->db->select('access_token', ['uid'], { token => $token })->hash;

	if (!defined $res) {
		return undef;
	}

	return $res->{uid};
}


1;
