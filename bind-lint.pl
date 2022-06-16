#!/usr/bin/perl
use warnings;
use strict;

use lib './lib';
use BIND::Config qw( check_config @zones );

my $debug = $ENV{DEBUG} || 0;

check_config( $ARGV[0] || "/etc/bind/named.conf" );

foreach my $z ( @zones ) {
	my ( $zone, $file ) = @$z;
	print "# $zone $file\n" if $debug;
	system "/usr/sbin/named-checkzone $zone $file";
}
