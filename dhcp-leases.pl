#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

use lib './lib';
use DHCPD::Leases qw(parse_leases);

my $debug = $ENV{DEBUG} || 0;

$|=1 if $debug;

my $lease = parse_leases( '/var/lib/dhcp/dhcpd.leases' );

foreach my $ip ( sort keys %$lease ) {
	my $data = $lease->{$ip};

	next if ( ! @ARGV && $data->{'binding state'} ne 'active' ); # FIXME
	warn "# ",dump($data) if $debug;
	print join(' ', map { defined $data->{$_} ? $data->{$_} : '?' } (
				'lease',
				'hardware ethernet',
				'binding state',
				'ends',
				'client-hostname',
				'ddns-fwd-name',
				'ddns-rev-name',
	)), "\n";
}
