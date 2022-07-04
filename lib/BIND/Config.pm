package BIND::Config;
use warnings;
use strict;

our @ISA = qw( Exporter );
our @EXPORT = qw( check_config @zones zone_local_ip );

# sudo apt install libparse-recdescent-perl libnet-subnet-perl

my $debug = $ENV{DEBUG} || 0;

use BIND::Config::Parser;
use Net::Subnet;
use Data::Dump qw(dump);

our @zones;

our $allow_update;
my $key_name;
our $key;
our $zone_local_ip;

sub strip_quotes {
	my $t = shift || die "no argument";
	$t =~ s/^"//;
	$t =~ s/"$//;
	return $t;
}

my @local_ips;

open(my $ipaddr, '-|', 'ip addr');
while(<$ipaddr>) {
	if ( m/^\s+inet\s([\d\.]+)/ ) {
		push @local_ips, $1;
	}
}
close($ipaddr);

warn "# local_ips = ",dump( \@local_ips ) if $debug;

my $in_match_clients = 0;
my @match_clients_ips;
my $local_ip;

my $indent = 0;

sub check_config {
	my ( $config_file ) = @_;
	warn "# check_config $config_file\n" if $debug;

	my $parser = new BIND::Config::Parser;
	 
	my $zone;
	my $type;
	 
	# Set up callback handlers
	$parser->set_open_block_handler( sub {
		print "\t" x $indent, join( " ", @_ ), " {\n" if $debug;
		print "# set_open_block_handler [$indent] ", join( "|", @_ ), "\n" if $debug > 1;
		$indent++;
		if ( $_[0] eq 'zone' ) {
			$zone = strip_quotes( $_[1] );
			if ( $local_ip ) {
				push @{ $zone_local_ip->{$zone} }, $local_ip;
				warn "## $zone local_ip $local_ip" if $debug;
			}
		}
		if ( $_[0] eq 'allow-update' ) {
			$allow_update->{$zone} = 1;
		}
		if ( $_[0] eq 'key' ) {
			$key_name = strip_quotes( $_[1] );
		}
		if ( $_[0] eq 'match-clients' ) {
			$in_match_clients = 1;
			@match_clients_ips = ();
		}
	} );
	$parser->set_close_block_handler( sub {
		$indent--;
		print "\t" x $indent, "};\n" if $debug;
		print "# set_close_block_handler [$indent] ", join( "|", @_ ), "\n" if $debug > 1;
		if ( $in_match_clients ) {
			$in_match_clients = 0;
			$local_ip = undef;
			my $local_matcher = subnet_matcher @match_clients_ips;
			foreach my $ip ( @local_ips ) {
				if ( $local_matcher->( $ip ) ) {
					$local_ip = $ip;
					#warn "# match_clients_ips = ",dump( \@match_clients_ips ), " local_ip: $local_ip" if $debug;
					last;
				}
			}
			die "can't find local_ip for ", dump( \@match_clients_ips ), " in local ips ", dump( \@local_ips ) unless $local_ip;
		}
	} );
	$parser->set_statement_handler( sub {
		print "\t" x $indent, join( " ", @_ ), ";\n" if $debug;
		print "# set_statement_handler [$indent] ", join( "|", @_ ), "\n" if $debug > 1;
		if ( $_[0] eq 'file' ) {
			my $file = strip_quotes( $_[1] );
			push @zones, [ $zone, $file ] if $type eq 'master';
		}
		if ( $_[0] eq 'include' ) {
			my $file = strip_quotes( $_[1] );
			check_config( $file );
		}
		if ( $_[0] eq 'key' ) {
			$allow_update->{$zone} = strip_quotes( $_[1] );
		}
		if ( $_[0] eq 'algorithm' || $_[0] eq 'secret' ) {
			$key->{ $key_name }->{$_[0]} = strip_quotes( $_[1] );
		}
		if ( $_[0] eq 'type' ) {
			$type = $_[1];
		}
		if ( $in_match_clients ) {
			push @match_clients_ips, $_[0];
		}

	} );

	# Parse the file
	$parser->parse_file( $config_file );

}

sub zone_local_ip {
	my $zone = shift;
	$zone =~ s/\.$//; # strip trailing dot
	if ( exists $zone_local_ip->{$zone} ) {
		return $zone_local_ip->{$zone}->[0];
	}
}

sub zone_key_name_secret {
    my $zone = shift;
	$zone =~ s/\.$//; # strip trailing dot
	my $key_name = $BIND::Config::allow_update->{$zone} || die "no zone $zone";
	return ( $key_name, $BIND::Config::key->{$key_name}->{secret} );
}

1;
