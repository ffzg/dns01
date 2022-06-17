package BIND::Config;
use warnings;
use strict;

our @ISA = qw( Exporter );
our @EXPORT = qw( check_config @zones );

# sudo apt install libparse-recdescent-perl

my $debug = $ENV{DEBUG} || 0;

use BIND::Config::Parser;

our @zones;

our $allow_update;
my $key_name;
our $key;

sub strip_quotes {
	my $t = shift || die "no argument";
	$t =~ s/^"//;
	$t =~ s/"$//;
	return $t;
}

sub check_config {
	my ( $config_file ) = @_;
	warn "# check_config $config_file\n" if $debug;

	my $parser = new BIND::Config::Parser;
	 
	my $indent = 0;
	my $zone;
	my $type;
	 
	# Set up callback handlers
	$parser->set_open_block_handler( sub {
		print "\t" x $indent, join( " ", @_ ), " {\n" if $debug;
		print "# set_open_block_handler [$indent] ", join( "|", @_ ), ";\n" if $debug > 1;
		$indent++;
		if ( $_[0] eq 'zone' ) {
			$zone = strip_quotes( $_[1] );
		}
		if ( $_[0] eq 'allow-update' ) {
			$allow_update->{$zone} = 1;
		}
		if ( $_[0] eq 'key' ) {
			$key_name = strip_quotes( $_[1] );
		}
	} );
	$parser->set_close_block_handler( sub {
		$indent--;
		print "\t" x $indent, "};\n" if $debug;
	} );
	$parser->set_statement_handler( sub {
		print "\t" x $indent, join( " ", @_ ), ";\n" if $debug;
		print "# set_statement_handler [$indent] ", join( "|", @_ ), ";\n" if $debug > 1;
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

	} );

	# Parse the file
	$parser->parse_file( $config_file );

}

1;
