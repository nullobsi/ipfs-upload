package IpfsUpload::Controller::Interface;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use IpfsUpload::Util;

sub landing($c) {
	if (!IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/login");
	}

	my $uid = $c->stash('uid');

	my $gateway = $c->config->{ipfs}->{gatewayPubUrl};

	my $limit = $c->param('limit') || 10;
	my $before = $c->param('before');

	my %query = (
		uid => $uid,
	);

	if (defined $before) {
		$query{created_at} = { '<' => $before };
	}

	$c->pins->list(\%query, $limit)->then(sub ($res) {
		$c->stash(
			pins    => $res,
			limit   => $limit,
			gateway => $gateway,
		);

		if (@$res == $limit) {
			$c->stash(nextPage => $res->[-1]->{created_at});
		} else {
			$c->stash(nextPage => 0);
		}

		$c->render('interface/landingPage');
	})
}

sub token_list($c) {
	# Token should only be managed through Session auth
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}
	$c->stash(uid => $c->session->{uid});

	return $c->users->list_tokens($uid)->then(sub ($tokens) {
		$c->stash(tokens => $tokens);
		$c->render('interface/tokens');
	})
}

sub gen_token_post($c) {
	# Token should only be managed through Session auth
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}
	$c->stash(uid => $c->session->{uid});

	my $v = $c->validation;
	return $c->render('interface/generateToken') unless $v->has_data;

	$v->required('app_name', 'trim')->size(1,64);
	return $c->render('interface/generateToken') if $v->has_error;

	my $app_name = $v->param('app_name');

	return $c->users->gen_token($uid, $app_name)->then(sub ($res) {
		$c->flash(msg => "Your new token is: $res");
		return $c->redirect_to('/my/tokens');
	});
}

sub gen_token_get($c) {
	# Token should only be managed through Session auth
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}
	$c->stash(uid => $c->session->{uid});

	return $c->render('interface/generateToken');
}

sub del_token($c) {
	# Token should only be managed through Session auth
	my $uid = $c->session->{uid};
	if (!defined $uid) {
		return $c->redirect_to("/login");
	}
	$c->stash(uid => $c->session->{uid});

	return $c->users->del_token($uid, $c->param('id'))->then(sub {
		$c->flash(msg => 'Token deleted.');
		return $c->redirect_to('/my/tokens')
	});
}

sub del_pin($c) {
	if (!IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/login");
	}
	my $uid = $c->stash('uid');
	my $id = $c->param('id');

	return $c->pins->get({
		id  => $id,
		uid => $uid,
	})->then(sub ($pin) {
		if (!defined $pin) {
			$c->flash(msg => "That pin doesn't exist.");
			return $c->redirect_to('/my/tokens');
		}

		# I wonder if this could cause a race condition.
		# Who cares!
		my $cid = $pin->{cid};

		return $c->pins->cid_count($cid)->then(sub ($count) {
			if ($count == 1) {
				my $url = Mojo::URL->new($c->config->{ipfs}->{gatewayWriteUrl});
				$url->path("api/v0/pin/rm");
				$url->query({
					arg       => $cid,
					recursive => "true",
				});

				return $c->ua->post_p($url);
			}

			return 1;
		})->then(sub ($tx) {
			if ($tx != 1) {
				my $res = $tx->result;
				if (!$res->is_success) {
					die "Could not delete pin!";
				}
			}

			return $c->pins->del({
				id  => $id,
			});
		})->then(sub {
			$c->flash(msg => "Pin deleted.");
			return $c->redirect_to('/my');
		});
	});
}

sub upload_post($c) {
	if (!IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/login");
	}
	my $uid = $c->stash('uid');
	my $app_name = $c->stash('app_name');

	my $file = $c->req->upload('file');
	my $filename = $file->filename;

	my $is_browser = $c->param('is_browser');

	# Ten megabytes
	my $max_size = 10 * 1024 * 1024;

	unless ($file) {
		$c->flash(msg => "No file specified.");
		return $c->redirect_to('/my');
	}

	if ($file->size > $max_size) {
		$c->flash(msg => "Max file size reached. (10MB)");
		return $c->redirect_to('/my');
	}

	# TODO: streaming somehow
	my $file_content = $file->slurp;

	my $ua = $c->ua;
	my $url = Mojo::URL->new($c->config->{ipfs}->{gatewayWriteUrl});

	my $pub_url = Mojo::URL->new($c->config->{ipfs}->{gatewayPubUrl});

	$url->path("api/v0/add");
	$url->query(
		progress => "false",
		pin      => "true",
	);
	return $ua->post_p($url => form => {
		file => {
			content        => $file_content,
			filename       => $filename,
			'Content-Type' => $file->headers->content_type,
		},
	})->then(sub ($tx) {
		my $res = $tx->result;

		if ($res->is_success) {
			# Now we do DB stuff.
			return $c->pins->add({
				cid      => $res->json->{Hash},
				name     => $filename,
				app_name => $app_name,
				uid      => $uid,
			});
		} else {
			# TODO: read error and use appropriate response
			warn $res->body;
			die "Failed to pin.";
		}
	})->then(sub ($res) {
		$pub_url->path($res->{cid});
		my $s = $pub_url->to_string;
		if ($is_browser) {
			$c->flash(msg => "File uploaded! $s");
			return $c->redirect_to("/my");
		}
		return $c->render(text => $s);
	});
}

sub upload_get ($c) {
	if (!IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/login");
	}
	return $c->render('interface/uploadPage');
}

sub import_post ($c) {
	if (!IpfsUpload::Util::check_auth($c)) {
		return $c->redirect_to("/login");
	}
	my $uid = $c->stash('uid');
	my $app_name = $c->stash('app_name');

	my $v = $c->validation;
	return $c->render('/') unless $v->has_data;

	$v->required('cid', 'trim')->size(1,128);
	$v->optional('name', 'trim')->size(1,512);
	$v->optional('is_browser');
	return $c->render('/') if $v->has_error;

	my $cid = $v->param('cid');
	my $name = $v->param('name');
	my $is_browser = $v->param('is_browser');

	my $pub_url = Mojo::URL->new($c->config->{ipfs}->{gatewayPubUrl});
	$pub_url->path($cid);
	$pub_url = $pub_url->to_string;

	return $c->pins->exists({
		cid => $cid,
		uid => $uid,
	})->then(sub ($exists){
		if ($exists == 1) {
			if ($is_browser) {
				$c->flash(msg => "Pin already exists: $pub_url");
				return $c->redirect_to('/my');
			} else {
				return $c->render(text => $pub_url);
			}
		}

		my $url = Mojo::URL->new($c->config->{ipfs}->{gatewayWriteUrl});
		$url->path("api/v0/pin/add");
		$url->query({
			arg       => $cid,
			recursive => "true",
			# It seems progress is a stream. Not sure how to handle that?
			# Let's just assume it works immediately.
			# TODO.
			progress  => "false",
		});

		return $c->ua->post_p($url)->then(sub($tx) {
			my $res = $tx->result;

			if ($res->is_success) {
				# Now we do DB stuff.
				return $c->pins->add({
					uid      => $uid,
					cid      => $cid,
					name     => $name,
					app_name => $app_name,
				});
			} else {
				# TODO: read error and use appropriate response
				warn $res->body;
				die "Failed to pin.";
			}
		})->then(sub($res) {
			if ($is_browser) {
				$c->flash(msg => "Pin added: $pub_url");
				return $c->redirect_to('/my');
			} else {
				return $c->render(text => $pub_url);
			}
		});
	});
}

1;
