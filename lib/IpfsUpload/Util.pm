package IpfsUpload::Util;
use strict;
use warnings FATAL => 'all';
use experimental qw/signatures/;

use Time::Piece;


sub date_format($date) {
	print "$date\n";
	$date =~ s/ /T/;
	$date =~ s/(\d\d)$/$1:00/;
	print "$date\n";
	return $date;
}

1;
