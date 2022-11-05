package IpfsUpload::Controller::Pins;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use IpfsUpload::Util;
use Mojo::UserAgent;

sub list($c) {
	$c->openapi->valid_input or return;

	my $uid = $c->stash('uid');

	$c->pins->list({
		uid => $uid,
	}, 10)->then(sub ($res) {

		my @formatted;

		for my $v (@$res) {
			push @formatted, {
				requestid => $v->{id},
				# TODO
				status    => "pinned",
				created   => IpfsUpload::Util::date_format($v->{created_at}),
				pin       => {
					cid  => $v->{cid},
					name => $v->{name},
				},
				delegates => $c->config->{ipfs}->{delegates},
			};
		}


		$c->render(openapi => {
			count   => scalar(@formatted),
			results => \@formatted,
		});
	});
}

sub get($c) {
	$c->openapi->valid_input or return;
	my $uid = $c->stash('uid');
	my $id = $c->param('requestid');

	return $c->pins->get({
		id => $id,
	})->then(sub ($pin) {
		if (!defined $pin) {
			return $c->render(status => 404, openapi => {
				error => {
					reason  => "NOT_FOUND",
					details => "The specified resource was not found",
				},
			})
		}

		# TODO: Should any pin be accessible to the public?
		if ($pin->{uid} ne $uid) {
			return $c->render(status => 401, openapi => {
				error => {
					reason => "UNAUTHORIZED",
					details => "You cannot view that pin.",
				},
			});
		}

		return $c->render(status => 200, openapi => {
			requestid => $pin->{id},
			# TODO
			status    => "pinned",
			created   => IpfsUpload::Util::date_format($pin->{created_at}),
			pin       => {
				cid  => $pin->{cid},
				name => $pin->{name},
			},
			delegates => $c->config->{ipfs}->{delegates},
		});
	});
}

sub delete($c) {
	$c->openapi->valid_input or return;
	my $uid = $c->stash('uid');
	my $id = $c->param('requestid');

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
					reason => "UNAUTHORIZED",
					details => "You cannot delete that pin.",
				},
			});
		}

		# I wonder if this could cause a race condition.
		# Who cares!
		my $cid = $pin->{cid};
		say $cid;

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

	my $body = $c->req->json;

	my $cid = $body->{cid};
	my $name = $body->{name};
	my $origins = $body->{origins};
	# No support for meta.

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
				uid  => $uid,
				cid  => $cid,
				name => $name,
			});
		} else {
			# TODO: read error and use appropriate response
			say $res->body;
			die "Failed to pin.";
		}
	})->then(sub($res) {
		$c->render(openapi => {
			requestid => $res->{id},
			# TODO
			status    => "pinned",
			created   => IpfsUpload::Util::date_format($res->{created_at}),
			pin       => {
				cid  => $cid,
				name => $name,
			},
			delegates => $c->config->{ipfs}->{delegates},
		}, status => 202)
	});
}

1;
