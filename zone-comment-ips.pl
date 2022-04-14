#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./zone-comment-ips.pl /etc/bind/hosts.db ~dpavlin/ips/ips.free 2>&1 | less

my ( $zone, $ips ) = @ARGV;
die "Usage: $0 zone ips" unless $zone && $ips;

my $ip_regex;

open(my $fh, '<', $ips);
$ip_regex = join('|', map { chomp; s/^193.198.21//; $_; } <$fh>);
$ip_regex = '\b193.198.21(' . $ip_regex . ')\b';
$ip_regex =~ s/\./\./g;
warn "# ip_regex $ip_regex";

open(my $z_in,  '<', $zone);
while(<$z_in>) {
	if ( m/$ip_regex/ ) {
		print ';XXX ', $_;
	} else {
		print $_;
	}
}
