package IpfsUpload;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Pg;
use IpfsUpload::Model::Users;
use IpfsUpload::Model::Pins;

# This method will run once at server start
sub startup($self) {

	# Load configuration from config file
	my $config = $self->plugin('NotYAMLConfig');

	$self->plugin(
		OpenAPI => {
			url      => $self->home->rel_file("ipfs-pinning-service.yaml"),
			security => {
				accessToken => sub($c, $def, $scopes, $cb) {
					my $auth = $c->req->headers->authorization;
					if (defined $auth) {
						$auth =~ s/Bearer //;
						my $uid = $c->users->id($auth);
						if (defined $uid) {
							$c->stash(uid => $uid);
							return $c->$cb();
						}
					}
					return $c->$cb('Authorization header not present');
				},
			},
		},
	);

	if ($config->{database}->{type} ne "postgres") {
		die "Only postgres is supported";
	}

	$self->helper(pg => sub ($app) {
		state $pg = Mojo::Pg->new($config->{'database'}->{connection});
	});

	$self->helper(pins => sub ($app) {
		state $pins = IpfsUpload::Model::Pins->new(pg => $app->pg);
	});

	$self->helper(users => sub ($app) {
		state $users = IpfsUpload::Model::Users->new(pg => $app->pg);
	});

	# Configure the application
	$self->secrets($config->{secrets});

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->get('/')->to('Example#welcome');
}

1;
