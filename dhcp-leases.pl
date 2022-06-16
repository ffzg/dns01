#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my $debug = $ENV{DEBUG} || 0;

$|=1 if $debug;

my $data;
my $lease;

open(my $fh, '<', '/var/lib/dhcp/dhcpd.leases');
while(<$fh>) {
	chomp;
	if ( m/(lease)\s+(\S+)\s\{/ ) {
		$data->{$1} = $2;
	} elsif ( m/\}/ ) {
		$lease->{$data->{lease}} = $data if exists $data->{lease};
		$data = undef;
	} elsif ( m/^\s+(\w+)\s\d\s(.+);$/ ) { # dates
		$data->{$1} = $2;
	} elsif ( m/^\s+([\w\s]+)\s(\S+);$/ ) {
		$data->{$1} = $2;
	} elsif ( m/^\s+set\s(\S+)\s=\s"([^"]+)";$/ ) {
		$data->{$1} = $2;
	} elsif ( m/^\s+(\S+)\s"([^"]+)";$/ ) {
		$data->{$1} = $2;
	} else {
		warn "IGNORE: ",dump($_),"\n" if $debug;
	}
}

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
