#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# ./zone-comment.pl /etc/bind/hosts.db   ~dpavlin/ips/ips.free > /tmp/zone.comment
# ./zone-comment.pl /etc/bind/hosts.rev212 /tmp/zone.extra.ptr > /tmp/hosts.rev212

my ( $zone, $ips ) = @ARGV;
die "Usage: $0 zone ips\n" unless $zone && $ips;

my $ip_regex;

open(my $fh, '<', $ips);
my ( $prefix, $suffix );
my @ips = map {
	chomp;
	my $line = $_;

	$prefix = $line if ! defined $prefix;
	$suffix = $line if ! defined $suffix;

	if ( $line !~ m/^\Q$prefix\E/ ) {
		my $l = length($prefix);
		foreach my $j ( 0 .. $l ) {
			my $i = $l - $j;
			if ( substr($line,0,$i) eq substr($prefix,0,$i) ) {
				$prefix = substr($prefix,0,$i);
				last;
			}
		}
	}

	if ( $line !~ m/\Q$suffix\E$/ ) {
		my $l = length($suffix);
		foreach my $j ( 0 .. $l ) {
			my $i = $l - $j;
			if ( substr($line,-$i,$i) eq substr($suffix,-$i,$i) ) {
				$suffix = substr($suffix,-$i,$i);
				last;
			}
		}
	}

	#warn "XXX [$prefix] $line [$suffix]\n";

	$line; 
} <$fh>;

warn "# prefix [$prefix]\n";
warn "# suffix [$suffix]\n";

$ip_regex = join('|', map { chomp; s/^\Q$prefix\E//; s/\Q$suffix\E$//; $_; } @ips);
$ip_regex = '\b' . $prefix . '(' . $ip_regex . ')' . $suffix;
$ip_regex =~ s/\./\\./g; # quote dots
warn "# ip_regex $ip_regex";

open(my $z_in,  '<', $zone);
while(<$z_in>) {
	if ( m/$ip_regex/ ) {
		print ';XXX ', $_;
	} else {
		print $_;
	}
}
