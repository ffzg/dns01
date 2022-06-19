#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# usage:
# ./nsupdate-delete.pl /tmp/nsupdate.delete | nsupdate -v -d && /usr/sbin/rndc sync -clean

use lib './lib';
use BIND::Config qw( check_config @zones zone_local_ip );

use Data::Dump qw(dump);

my $debug = $ENV{DEBUG} || 0;

$|=1 if $debug;

check_config( "/etc/bind/named.conf" );

my $dynamic_regex = '(' . join('|', keys %{ $BIND::Config::allow_update } ) . ')\.';

my $update;

while(<>) {
	chomp;
	my $name = $_;
	warn "# $name\n";

	if ( $name =~ m/$dynamic_regex/ ) {
		push @{ $update->{$1} }, $name;
	} else {
		die "not dynamic ip $name";
	}

}

warn "# update = ",dump($update) if $debug;

foreach my $zone ( keys %$update ) {

	if ( $ENV{FILE} ) {
		open(STDOUT, '>', "/tmp/nsupdate.zone.$zone");
	}

	print "zone $zone\n";

	my ( $key_name, $secret ) = BIND::Config::zone_key_name_secret( $zone );
	# key [hmac:] {keyname} {secret}
	print "key $key_name $secret\n";

	if ( my $ip = zone_local_ip( $zone ) ) {
		print "server $ip\n";
		print "local $ip\n";
	}

	my $count = 0;

	foreach my $name ( @{ $update->{$zone} } ) {
		if ( $zone =~ m/\.arpa$/ ) {
			print "delete $name PTR\n";
			$count++;
		} else {
			print "delete $name A\n";
			print "delete $name TXT\n";
			$count++;
		}
		print "send\n" if $count % 10 == 0; # prevent dns_request_createvia: ran out of space
	}

	print "send\n";
}

