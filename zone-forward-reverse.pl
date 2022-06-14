#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

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
	return $full_name;
}

foreach my $zone_file ( qw(
/etc/bind/hosts.db
/etc/bind/hosts.rev212
/etc/bind/hosts.rev213
) ) {

	open(my $fh, '<', $zone_file);
	while(<$fh>) {
		chomp;
		print "# $zone_file: $_\n";
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
			print "++ $name $in $v\n";
		}
	}

}

print "# zone = ",dump( $zone );
