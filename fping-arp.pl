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

my $tmp_file = '/dev/shm/fping-arp';
open(my $tmp, '>', $tmp_file);

open(my $arp, '-|', '/usr/sbin/arp -a');
while(<$arp>) {
	chomp;
	#warn "# $_\n";
	my ( $hostname, $ip, undef, $mac ) = split(/\s/,$_);
	$ip =~ s/^\(//;
	$ip =~ s/\)$//;
	if ( $ip =~ m/$ips_regex/ ) {
		print "$hostname $ip $mac\n";
		print $tmp "$hostname $ip $mac\n";
	}
}
close($arp);
close($tmp);

warn "# $tmp_file ", -s $tmp_file, " bytes created\n";
