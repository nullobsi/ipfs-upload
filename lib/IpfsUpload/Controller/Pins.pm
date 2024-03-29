package IpfsUpload::Controller::Pins;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use IpfsUpload::Util;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

# Form CID object, seperate so we can leave {name}
# out of it
sub pin_obj($name, $cid) {
	my %cidobj = ();
	$cidobj{cid} = $cid;
	$cidobj{name} = $name if defined $name;
	return \%cidobj;
}

sub list($c) {
	$c->openapi->valid_input or return;

	my $uid = $c->stash('uid');

	my $limit = $c->param('limit') || 10;
	my %query = (
		uid => $uid,
	);

	if (!IpfsUpload::Util::update_query($c, \%query)) {
		# Error!
		return;
	}

	$c->pins->count(\%query)->then(sub ($count) {
		$c->pins->list(\%query, $limit)->then(sub ($res) {

			my @formatted;

			for my $v (@$res) {
				push @formatted, {
					requestid => $v->{id},
					# TODO
					status    => "pinned",
					created   => IpfsUpload::Util::date_format($v->{created_at}),
					pin       => pin_obj($v->{name}, $v->{cid}),
					delegates => $c->config->{ipfs}->{delegates},
					meta      => { app_name => $v->{app_name}},
				};
			}


			$c->render(openapi => {
				count   => $count,
				results => \@formatted,
			});
		});
	});
}

sub get($c) {
	$c->openapi->valid_input or return;
	my $uid = $c->stash('uid');
	my $id = $c->param('requestid');

	return $c->pins->get({
		uid => $uid,
		id  => $id,
	})->then(sub ($pin) {
		if (!defined $pin) {
			return $c->render(status => 404, openapi => {
				error => {
					reason  => "NOT_FOUND",
					details => "The specified resource was not found",
				},
			})
		}

		return $c->render(status => 200, openapi => {
			requestid => $pin->{id},
			# TODO
			status    => "pinned",
			created   => IpfsUpload::Util::date_format($pin->{created_at}),
			pin       => pin_obj($pin->{name}, $pin->{cid}),
			delegates => $c->config->{ipfs}->{delegates},
			meta      => { app_name => $pin->{app_name}},
		});
	});
}

sub replace($c) {
	$c->openapi->valid_input or return;
	my $uid = $c->stash('uid');
	my $app_name = $c->stash('app_name');
	my $id = $c->param('requestid');

	my $body = $c->req->json;

	my $cid = $body->{cid};
	my $name = $body->{name};
	my $origins = $body->{origins};
	# No support for meta.

	return $c->pins->get({
		id => $id,
	})->then(sub ($pin) {
		if (!defined $pin) {
			return $c->render(status => 404, openapi => {
				error => {
					reason  => "NOT_FOUND",
					details => "The specified resource was not found",
				},
			});
		}
		if ($pin->{uid} ne $uid) {
			return $c->render(status => 401, openapi => {
				error => {
					reason  => "UNAUTHORIZED",
					details => "You cannot replace that pin.",
				},
			});
		}

		# Begin add process
		my @requests;

		push @requests, Mojo::Promise->resolve(1);

		# Firstly try to direct to possible origins.
		if (defined $origins) {
			for my $origin (@$origins) {
				my $url = Mojo::URL->new($c->config->{ipfs}->{gatewayWriteUrl});
				$url->path("api/v0/swarm/peering/add");
				$url->query({
					arg => $origin,
				});

				push @requests, $c->ua->post_p($url);
			}
		}

		Mojo::Promise->all_settled(@requests)->then(sub(@results) {
			# I had to look at the sourcecode for this.
			# my $peer_failed = 0;
			# for my $res (@results) {
			# 	if ($res->{status} eq 'fulfilled') {
			# 		my $tx = $res->{value};
			#
			# 		# Handle first initial empty promise
			# 		if ($tx == 1) {
			# 			next;
			# 		}
			#
			# 		if (!$tx->result->is_success) {
			# 			say "Failure to add IPFS peer.";
			# 			$peer_failed = 1;
			# 			last;
			# 		}
			# 	} else {
			# 		say "Failure to connect!";
			# 		die $res->{reason};
			# 	}
			# }

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

			return $c->ua->post_p($url);
		})->then(sub($tx) {
			my $res = $tx->result;

			if ($res->is_success) {
				# Now we do DB stuff.
				return $c->pins->update({
					cid      => $cid,
					name     => $name,
					app_name => $app_name,
				}, {
					id => $id,
				});
			} else {
				# TODO: read error and use appropriate response
				warn $res->body;
				die "Failed to pin.";
			}
		})->then(sub($res) {
			if (!defined $res) {
				die "DB Failure";
			}

			# Now do deletion of previous CID.
			return $c->pins->cid_count($pin->{cid});
		})->then(sub($count) {
			# Zero this time, since we already replaced the DB entry.
			if ($count == 0) {
				my $url = Mojo::URL->new($c->config->{ipfs}->{gatewayWriteUrl});
				$url->path("api/v0/pin/rm");
				$url->query({
					arg       => $pin->{cid},
					recursive => "true",
				});

				return $c->ua->post_p($url);
			}

			return 1;
		})->then(sub($tx) {
			if ($tx != 1) {
				my $res = $tx->result;
				if (!$res->is_success) {
					die "Could not delete pin!";
				}
			}

			return $c->render(openapi => {
				requestid => $id,
				# TODO
				status    => "pinned",
				created   => IpfsUpload::Util::date_format($pin->{created_at}),
				pin       => pin_obj($name, $cid),
				delegates => $c->config->{ipfs}->{delegates},
				meta      => { app_name => $app_name},
			}, status => 202);
		});
	});
}

sub delete($c) {
	$c->openapi->valid_input or return;
	my $uid = $c->stash('uid');
	my $id = $c->param('requestid');

	return $c->pins->get({
		id  => $id,
		uid => $uid,
	})->then(sub ($pin) {
		if (!defined $pin) {
			return $c->render(status => 404, openapi => {
				error => {
					reason  => "NOT_FOUND",
					details => "The specified resource was not found",
				},
			});
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
			$c->render(status => 202, openapi => "");
		});
	});
}

sub add($c) {
	$c->openapi->valid_input or return;
	my $uid = $c->stash('uid');
	my $app_name = $c->stash('app_name');

	my $body = $c->req->json;

	my $cid = $body->{cid};
	my $name = $body->{name};
	my $origins = $body->{origins};
	# No support for meta.

	return $c->pins->exists({
		cid => $cid,
		uid => $uid,
	})->then(sub ($exists){
		if ($exists == 1) {
			return $c->render(status => 400, openapi => {
				error => {
					reason  => "ALREADY_PINNED",
					details => "You already have that CID pinned.",
				},
			});
		}
		my @requests;

		push @requests, Mojo::Promise->resolve("FIRST");

		# Firstly try to direct to possible origins.
		if (defined $origins) {

			for my $origin (@$origins) {
				my $url = Mojo::URL->new($c->config->{ipfs}->{gatewayWriteUrl});
				$url->path("api/v0/swarm/peering/add");
				$url->query({
					arg => $origin,
				});

				push @requests, $c->ua->post_p($url);
			}
		}

		Mojo::Promise->all_settled(@requests)->then(sub(@results) {
			# I had to look at the sourcecode for this.
			# my $peer_failed = 0;
			# for my $res (@results) {
			# 	if ($res->{status} eq 'fulfilled') {
			# 		my $tx = $res->{value};
			#
			# 		# Handle first initial empty promise
			# 		if ($tx eq "FIRST") {
			# 			next;
			# 		}
			#
			# 		if (!$tx->result->is_success) {
			# 			say "Failure to add IPFS peer.";
			# 			$peer_failed = 1;
			# 			last;
			# 		}
			# 	} else {
			# 		say "Failure to connect!";
			# 		die $res->{reason};
			# 	}
			# }

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

			return $c->ua->post_p($url);
		})->then(sub($tx) {
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
			$c->render(openapi => {
				requestid => $res->{id},
				# TODO
				status    => "pinned",
				created   => IpfsUpload::Util::date_format($res->{created_at}),
				pin       => pin_obj($name, $cid),
				delegates => $c->config->{ipfs}->{delegates},
				meta      => { app_name => $app_name},
			}, status => 202)
		});
	});
}

1;
