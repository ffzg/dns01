#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# usage:
# ./nsupdate-delete.pl /tmp/nsupdate.delete | nsupdate -v -d && /usr/sbin/rndc sync -clean

use lib './lib';
use BIND::Config qw( check_config @zones );

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

	print "zone $zone\n";

	my $zone_no_dot = $zone;
	$zone_no_dot =~ s/\.$//;
	my $key_name = $BIND::Config::allow_update->{$zone_no_dot} || die "no zone $zone";

	# key [hmac:] {keyname} {secret}
	print "key $key_name ", $BIND::Config::key->{$key_name}->{secret}, "\n";

	foreach my $name ( @{ $update->{$zone} } ) {
		if ( $zone =~ m/\.arpa$/ ) {
			print "delete $name PTR\n";
		} else {
			print "delete $name A\n";
			print "delete $name TXT\n";
		}
	}

	print "send\n";
}

