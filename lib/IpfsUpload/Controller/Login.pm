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

	if ($config->{auth} eq 'ldap') {
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
			$c->flash(msg => "Logged in.");
			$c->redirect_to('/my');
		})->catch(sub ($err) {
			$c->flash(msg => "Login failed.");
			$c->redirect_to('/login');
		});
	} elsif ($config->{auth} eq 'db') {
		return $c->users->get($username)->then(sub ($uid) {
			if (!defined $uid) {
				$c->flash(msg => "Login failed.");
				return $c->redirect_to('/login');
			}
			return $c->users->get_pass_hash($uid)->then(sub ($hash) {
				if (IpfsUpload::Util::check_pass($password, $hash)) {
					$c->session->{uid} = $uid;
					$c->flash(msg => "Logged in.");
					return $c->redirect_to('/my');
				}
				die "Login failed.";
			});
		})->catch(sub ($err) {
			$c->flash(msg => "Login failed.");
			$c->redirect_to('/login');
		});
	}
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
