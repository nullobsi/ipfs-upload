package IpfsUpload::Controller::Login;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use IpfsUpload::Util;
use Net::LDAPS;

sub auth($c) {
	my $v = $c->validation;
	return $c->render('login/login') unless $v->has_data;

	$v->required('username', 'trim')->size(1,32)->like(qr/^([a-z_][a-z0-9_-]*[\$]?)$/);
	$v->required('password');
	return $c->render('login/login') if $v->has_error;


	my $username = $c->param('username');
	my $password = $c->param('password');

	my $config = $c->config;

	my $connStr = $config->{'ldap'}->{'uri'};
	my $bindDN = $config->{'ldap'}->{'dnBase'};
	$bindDN =~ s/%u/$username/;

	return Mojo::IOLoop->subprocess->run_p(sub {
		my $ldap=  Net::LDAPS->new($connStr, verify=>'none', version=>3) or die "$@";
		my $mesg = $ldap->bind($bindDN, password=>$password);
		$mesg->code and die $mesg->error;
	})->then(sub ($res) {
		return $c->users->getOrMake($username);
	})->then(sub ($res) {
		$c->session->{uid} = $res;
		$c->flash(message => "Logged in.");
		$c->redirect_to('/my');
	});
}

sub login($c) {
	if (IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/my");
	}
	return $c->render();
}

sub logout($c) {
	delete $c->session->{uid};
	return $c->redirect_to('/login');
}

1;
