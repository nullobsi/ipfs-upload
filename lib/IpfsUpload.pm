package IpfsUpload;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Pg;
use Mojo::SQLite;
use IpfsUpload::Model::Users;
use IpfsUpload::Model::Pins;
use IpfsUpload::Util;

# This method will run once at server start
sub startup($self) {

	# Load configuration from config file
	my $config = $self->plugin('NotYAMLConfig');

	$self->plugin(
		OpenAPI => {
			url      => $self->home->rel_file("ipfs-pinning-service.yaml"),
			security => {
				accessToken => sub($c, $def, $scopes, $cb) {
					if (IpfsUpload::Util::check_auth($c)) {
						return $c->$cb();
					} else {
						return $c->$cb('Authorization header not present');
					}
				},
			},
		},
	);

	my @dbs = qw/postgres sqlite/;
	my $dbtype = $config->{database}->{type};
	if (not grep $_ eq $dbtype, @dbs) {
		die "Database type is not supported";
	}

	my @auths = qw/ldap db/;
	my $auth = $config->{auth};
	if (not grep $_ eq $auth, @auths) {
		die "Auth type is not supported";
	}

	$self->helper(sql => sub ($app) {
		if ($dbtype eq "postgres") {
			state $sql = Mojo::Pg->new($config->{database}->{connection});
		} elsif ($dbtype eq "sqlite") {
			state $sql = Mojo::SQLite->new($config->{database}->{connection});
		}
	});

	$self->helper(pins => sub ($app) {
		state $pins = IpfsUpload::Model::Pins->new(sql => $app->sql);
	});

	$self->helper(users => sub ($app) {
		state $users = IpfsUpload::Model::Users->new(sql => $app->sql);
	});

	# Configure the application
	$self->secrets($config->{secrets});
	$self->max_request_size($config->{max_upload_size});

	# Router
	my $r = $self->routes;

	# Normal route to controller
	$r->get('/login')->to('Login#login');
	$r->get('/my/logout')->to('Login#logout');
	$r->post('/auth')->to('Login#auth');
	$r->post('/my/password')->to('Login#change_password');
	$r->get('/my')->to('Interface#landing');
	$r->get('/my/tokens')->to('Interface#token_list');

	$r->get('/my/tokens/generate')->to('Interface#gen_token_get');
	$r->post('/my/tokens/generate')->to('Interface#gen_token_post');
	$r->get('/my/tokens/#id/delete')->to('Interface#del_token');
	$r->get('/my/pins/#id/delete')->to('Interface#del_pin');

	$r->get('/')->to('Interface#upload_get');
	$r->post('/')->to('Interface#upload_post');

	$r->post('/my/import')->to('Interface#import_post');
}

1;
