package IpfsUpload::Controller::Login;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Net::LDAPS;
use Net::LDAP::Extension::SetPassword;

sub auth($c) {
	$c->openapi->valid_input or return;

	my $token = $c->req->headers->authorization;

	$c->render(openapi => {
		count   => 0,
		results => [],
	});
}

1;
