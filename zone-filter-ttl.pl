#!/usr/bin/perl
use warnings;
use strict;

# generate nsupdate command to remove all entries which have wrong ttl
# usage: ./zone-filter-ttl.pl /etc/bind/db.eduroam > /tmp/delete-ttl

my $wanted_ttl = 360; # from /etc/dhcp/conf4.d/eduroam-wlan.conf default-lease-time
my $ttl = -1;
my $name = '?';
my ($op,$v);

my $zone = '?';

while(<>) {
    chomp;

    if ( m/(\S+)\s+IN\s+SOA/i ) {
        $zone = $1;
        warn "# ZONE: $zone\n";
        next;
    }

    if ( $ttl == -1 ) { # skip beginning
        if ( m/\$ORIGIN $zone/ ) {
            $ttl = 0; # start parsing
        } else {
            warn "SKIP [$_}\n";
        }
        next;
    }


    if ( m/\$TTL\s+(\d+)/ ) {
        $ttl = $1;
        next;
    }

    if ( m/^(\S+)\s+(\S+)\s+(\S+)\s*$/ ) { # line with name
        $name = $1;
        $op = $2;
        $v = $3;
    } elsif ( m/^\s+(\S+)\s+(\S+)\s*$/ ) { # continuation for same name
        $op = $1;
        $v = $2;
    } else {
        warn "IGNORED: [$_]\n";
        next;
    }

    if ( $ttl != $wanted_ttl ) {

        next if $name eq '?';

        warn "[$ttl] $name $op $v\n";
        print "update delete $name.$zone $op\n";
        print "send\n";
    }
}


