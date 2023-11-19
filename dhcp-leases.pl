#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

use lib './lib';
use DHCPD::Leases qw(parse_leases);
use HTTP::Date;

my $debug = $ENV{DEBUG} || 0;

$|=1 if $debug;

my $stat;
my $lease = parse_leases( '/var/lib/dhcp/dhcpd.leases' );

foreach my $ip ( sort keys %$lease ) {
	my $data = $lease->{$ip};

	$stat->{ $data->{'binding state'} }++;

	next if ( ! @ARGV && $data->{'binding state'} ne 'active' ); # FIXME
	warn "# ",dump($data) if $debug;
	my $starts_t = str2time $data->{'starts'};
	my $ends_t = str2time $data->{'ends'};
	my $d_t = $ends_t - $starts_t;
	$data->{d_t} = $d_t;
	print "XX lease time $d_t ",dump($data) if $debug && $d_t > 600;
	print join(' ', map { defined $data->{$_} ? $data->{$_} : '?' } (
				'lease',
				'hardware ethernet',
				'binding state',
				'ends',
				'd_t',
				'client-hostname',
				'ddns-fwd-name',
				'ddns-rev-name',
	)), "\n";
}

print "# binding state = ",dump($stat);
