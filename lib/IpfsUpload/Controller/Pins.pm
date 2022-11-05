package IpfsUpload::Controller::Pins;
use strict;
use warnings FATAL => 'all';
use experimental q/signatures/;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use IpfsUpload::Util;

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

1;
