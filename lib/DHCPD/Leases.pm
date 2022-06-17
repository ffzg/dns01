package DHCPD::Leases;
use warnings;
use strict;
use autodie;

our @ISA = qw( Exporter );
our @EXPORT = qw( parse_leases );

my $debug = $ENV{DEBUG} || 0;

sub parse_leases {
	my $path = shift || '/var/lib/dhcp/dhcpd.leases';

	my $data;
	my $lease;

	open(my $fh, '<', $path);
	while(<$fh>) {
		chomp;
		if ( m/(lease)\s+(\S+)\s\{/ ) {
			$data->{$1} = $2;
		} elsif ( m/\}/ ) {
			$lease->{$data->{lease}} = $data if exists $data->{lease};
			$data = undef;
		} elsif ( m/^\s+(\w+)\s\d\s(.+);$/ ) { # dates
			$data->{$1} = $2;
		} elsif ( m/^\s+([\w\s]+)\s(\S+);$/ ) {
			$data->{$1} = $2;
		} elsif ( m/^\s+set\s(\S+)\s=\s"([^"]+)";$/ ) {
			$data->{$1} = $2;
		} elsif ( m/^\s+(\S+)\s"([^"]+)";$/ ) {
			$data->{$1} = $2;
		} else {
			warn "IGNORE: ",dump($_),"\n" if $debug;
		}
	}

	return $lease;
}

1;
