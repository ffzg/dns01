#!/usr/bin/perl
use warnings;
use strict;

use Data::Dump qw(dump);

use lib './lib';
use BIND::Config qw( check_config @zones );

my $debug = $ENV{DEBUG} || 0;
$| = 1 if $debug;

check_config( $ARGV[0] || "/etc/bind/named.conf" );

print "zones = ",dump( @zones ), "\n";

print "allow_update = ",dump( $BIND::Config::allow_update ), "\n";
print "key = ",dump( $BIND::Config::key ), "\n";
print "zone_local_ip = ",dump( $BIND::Config::zone_local_ip ), "\n";
