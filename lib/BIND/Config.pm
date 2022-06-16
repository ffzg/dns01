package BIND::Config;
use warnings;
use strict;

our @ISA = qw( Exporter );
our @EXPORT = qw( check_config @zones );

# sudo apt install libparse-recdescent-perl

my $debug = $ENV{DEBUG} || 0;

use BIND::Config::Parser;

our @zones;

sub check_config {
	my ( $config_file ) = @_;
	warn "# check_config $config_file\n" if $debug;

	my $parser = new BIND::Config::Parser;
	 
	my $indent = 0;
	my $zone;
	 
	# Set up callback handlers
	$parser->set_open_block_handler( sub {
		print "\t" x $indent, join( " ", @_ ), " {\n" if $debug;
		$indent++;
		if ( $_[0] eq 'zone' ) {
			$zone = $_[1];
		}
	} );
	$parser->set_close_block_handler( sub {
		$indent--;
		print "\t" x $indent, "};\n" if $debug;
	} );
	$parser->set_statement_handler( sub {
		print "\t" x $indent, join( " ", @_ ), ";\n" if $debug;
		if ( $_[0] eq 'file' ) {
			my $file = $_[1];
			$file =~ s/^"//;
			$file =~ s/"$//;
			push @zones, [ $zone, $file ];
		}
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

1;
