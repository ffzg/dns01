#!/usr/bin/perl
use warnings;
use strict;

# sudo apt install libparse-recdescent-perl

use lib './lib';
use BIND::Config::Parser;

my @zones;

sub check_config {
	my ( $config_file ) = @_;
	warn "# check_config $config_file\n";
	return if $config_file =~ m/\.options/; # FIXME skip file we can't parse

	my $parser = new BIND::Config::Parser;
	 
	my $indent = 0;
	my $zone;
	 
	# Set up callback handlers
	$parser->set_open_block_handler( sub {
		print "\t" x $indent, join( " ", @_ ), " {\n";
		$indent++;
		warn "## $_[0]\n";
		if ( $_[0] eq 'zone' ) {
			$zone = $_[1];
		}
	} );
	$parser->set_close_block_handler( sub {
		$indent--;
		print "\t" x $indent, "};\n";
	} );
	$parser->set_statement_handler( sub {
		print "\t" x $indent, join( " ", @_ ), ";\n";
		if ( $_[0] eq 'file' ) {
			push @zones, [ $zone, $_[1] ];
		}
		warn "## statement $_[0] [$_[1]]\n";
		if ( $_[0] eq 'include' ) {
			my $file = $_[1];
			$file =~ s/^"//;
			$file =~ s/"$//;
			check_config( $file );
		}
	} );

	# Parse the file
	$parser->parse_file( $config_file );

}

check_config( "/etc/bind/named.conf" );

foreach my $z ( @zones ) {
	my ( $zone, $file ) = @$z;
	print "# $zone $file\n";
	system "/usr/sbin/named-checkzone $zone $file";
}
