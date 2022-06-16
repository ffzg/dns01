#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use lib './lib';
use BIND::Config qw( check_config @zones );

use Data::Dump qw(dump);

my $debug = $ENV{DEBUG} || 0;

my $zone;
my $stat;

my $origin;
my $name;
sub full_name {
	my $full_name = shift;
	return lc($full_name) if $full_name =~ m/\.$/;
	$full_name .= '.';
	$full_name .= $origin;
	$full_name =~ s/\.\.+$/\./;
	$full_name .= '.' unless $full_name =~ m/\.$/;
	return lc($full_name);
}

check_config( $ARGV[0] || "/etc/bind/named.conf" );

foreach my $zone_name_file ( @zones ) {

	my ( $zone_name, $zone_file ) = @$zone_name_file;

	open(my $fh, '<', $zone_file);
	while(<$fh>) {
		chomp;
		print "# $zone_file: $_\n" if $debug;
		if ( m/^\s*;/ || m/^$/ ) {
			next;
		} elsif ( m/^\s*\$ORIGIN\s(\S+)/ ) {
			$origin = $1;
		} elsif ( m/^(\S+)\s/ ) {
			$name = $1;
		}
		
		if ( m/\s(A|CNAME|PTR)\s+(\S+)/ ) {
			my ($in,$v) = ($1,$2);
			push @{ $zone->{uc($in)}->{ full_name( $name ) } }, $in eq 'A' ? $v : full_name( $v );
			print "++ $name $in $v\n" if $debug;
		}
	}

}

print "# zone = ",dump( $zone ) if $debug;

foreach my $name ( keys %{ $zone->{A} } ) {
	foreach my $ip ( @{ $zone->{A}->{$name} } ) {
		my $ptr = join('.', reverse split(/\./,$ip)) . '.in-addr.arpa.';
		if ( exists $zone->{PTR}->{$ptr} ) {
			if ( grep { $_ eq $name } @{ $zone->{PTR}->{$ptr} } ) {
				print "OK $name $ip has $ptr\n";
				$stat->{ok}->{ptr}++;
			} else {
				print "ADDITIONAL $ptr IN PTR $name\n", "# ",dump( $zone->{PTR}->{$ptr} ), "\n";
				$stat->{additional}->{ptr}++;
			}
		} else {
			print "MISSING $ptr IN PTR $name\n";
			$stat->{missing}->{ptr}++;
		}
	}
}

foreach my $name ( keys %{ $zone->{CNAME} } ) {
	foreach my $t ( @{ $zone->{CNAME}->{$name} } ) {
		if ( exists $zone->{A}->{$t} ) {
			print "OK CNAME $name -> A $t\n";
			$stat->{ok}->{cname_a}++;
		} elsif ( exists $zone->{CNAME}->{$t} ) {
			print "OK CNAME $name -> CNAME $t\n";
			$stat->{ok}->{cname_cname}++;
		} else {
			print "CNAME $name MISSING $t\n";
			$stat->{missing}->{cname}++;
		}
	}
}

foreach my $name ( keys %{ $zone->{PTR} } ) {
	foreach my $t ( @{ $zone->{PTR}->{$name} } ) {
		if ( exists $zone->{A}->{$t} ) {
			print "OK PTR $name -> A $t\n";
			$stat->{ok}->{ptr_a}++;
		} elsif ( exists $zone->{CNAME}->{$t} ) {
			print "OK PTR $name -> CNAME $t\n";
			$stat->{ok}->{ptr_cname}++;
		} else {
			print "PTR $name EXTRA $t\n";
			$stat->{extra}->{ptr}++;
		}
	}
}

print "# stat = ",dump($stat);
