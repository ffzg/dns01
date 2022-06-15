#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my $debug = $ENV{DEBUG} || 0;

my $zone;

my $origin;
my $name;
sub full_name {
	my $full_name = shift;
	return $full_name if $full_name =~ m/\.$/;
	$full_name .= '.';
	$full_name .= $origin;
	$full_name =~ s/\.\.+$/\./;
	$full_name .= '.' unless $full_name =~ m/\.$/;
	return lc($full_name);
}

foreach my $zone_file ( qw(
/etc/bind/hosts.db
/etc/bind/hosts.rev212
/etc/bind/hosts.rev213
) ) {

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
			} else {
				print "ADDITIONAL $ptr IN PTR $name\n", "# ",dump( $zone->{PTR}->{$ptr} ), "\n";
			}
		} else {
			print "MISSING $ptr IN PTR $name\n";
		}
	}
}
