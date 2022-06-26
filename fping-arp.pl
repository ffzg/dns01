#!/usr/bin/perl
use warnings;
use strict;
my $alive = 0;

my $debug = $ENV{DEBUG} || 0;

my @ips = @ARGV;
die "usage: $0 ip [ip..]\n" unless @ips;
warn "# ips ",join(' ', @ips) if $debug;

my @regex;

open(my $fping, '-|', "fping -d -A @ips 2>/dev/null");
while(<$fping>) {
	chomp;
	#warn "# $_\n";
	my ( $hostname, $ip ) = split(/\s/,$_);
	push @regex, $ip;
}

warn "# regex = ",join(' ', @regex) if $debug;

die "no regex" unless @regex;

my $ips_regex = '\b(' . join('|', @regex) . ')\b';
warn "# ips_regex = $ips_regex" if $debug;

open(my $arp, '-|', '/usr/sbin/arp -a');
while(<$arp>) {
	chomp;
	#warn "# $_\n";
	my ( $hostname, $ip, undef, $mac ) = split(/\s/,$_);
	$ip =~ s/^\(//;
	$ip =~ s/\)$//;
	print "$hostname $ip $mac\n" if $ip =~ m/$ips_regex/;
}
