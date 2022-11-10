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
						my $tinfo = $c->users->token_info($auth);
						if (defined $tinfo) {
							$c->stash(
								uid => $tinfo->{uid},
								app_name => $tinfo->{app_name}
							);
							return $c->$cb();
						}
					}

					# Try session auth
					my $uid = $c->session->{uid};
					if (defined $uid) {
						$c->stash(
							uid      => $uid,
							app_name => 'WebInterface',
						);
						return $c->$cb();
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
	$r->get('/login')->to('Login#login');
	$r->post('/auth')->to('Login#auth');
	$r->get('/my')->to('Interface#landing');
	$r->get('/my/tokens')->to('Interface#token_list');

	$r->get('/my/tokens/generate')->to('Interface#gen_token_get');
	$r->post('/my/tokens/generate')->to('Interface#gen_token_post');
	$r->get('/my/tokens/#id/delete')->to('Interface#del_token');
	$r->get('/my/pins/#id/delete')->to('Interface#del_pin');
}

1;
