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
			return $c->users->get_or_make($username);
		})->then(sub ($res) {
			$c->session->{uid} = $res;
			$c->flash(msg => "Logged in.");
			$c->redirect_to('/my');
		})->catch(sub ($err) {
			$c->flash(msg => "Login failed.");
			$c->redirect_to('/login');
		});
	} elsif ($config->{auth} eq 'db') {
		# Check if whitelisted
		if (not grep $_ eq $username, @{$config->{whitelist_names}}) {
			$c->flash(msg => "Login failed.");
			return $c->redirect_to('/login');
		}

		# Attempt to get user from username
		return $c->users->get($username)->then(sub ($uid) {
			# Create if not exists
			if (!defined $uid) {
				# Hash pass + insert and create user
				my $hash = IpfsUpload::Util::add_pass($password);
				return $c->users->make_with_pass($username, $hash)->then(sub ($uid_new) {
					$c->session->{uid} = $uid_new;
					$c->flash(msg => "Logged in.");
					return $c->redirect_to('/my');
				});
			}

			# Verify password
			return $c->users->get_pass_hash($uid)->then(sub ($hash) {
				if (IpfsUpload::Util::check_pass($password, $hash)) {
					$c->session->{uid} = $uid;
					$c->flash(msg => "Logged in.");
					return $c->redirect_to('/my');
				}
				die "Login failed.";
			});
		})->catch(sub ($err) {
			say $err;
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

sub change_password($c) {
	if (!IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/login");
	}

	if ($c->config->{auth} ne 'db') {
		return $c->redirect_to('/my');
	}

	my $uid = $c->stash('uid');
	my $v = $c->validation;
	$v->required('password');
	return $c->redirect_to('/my') if $v->has_error;

	my $password = $c->param('password');
	return $c->users->set_pass_hash($uid, IpfsUpload::Util::add_pass($password))->then(sub {
		$c->flash(msg => "Password set.");
		return $c->redirect_to('/my');
	});
}

1;
