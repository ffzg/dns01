#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

use lib './lib';
use DHCPD::Leases qw(parse_leases);
use HTTP::Date;
use Getopt::Long;
use Net::IP;
use Net::Netmask;

my $debug = $ENV{DEBUG} || 0;
my $all;
my $long;

GetOptions(
#"length=i" => \$length,    # numeric
#"file=s"   => \$data,      # string
"debug"  => \$debug,  # flag
"all"  => \$all,
"long"  => \$long,
) or die "$0 arguments @ARGV error";

$|=1 if $debug;

my $stat;

my $CONFIGFILE = '/etc/dhcp/dhcpd.conf';
parseconfig($CONFIGFILE);

# isc-dhcp-server config parser from munin plugin dhcpd3

my @netmasks;

sub parseconfig {
    my($configfile) = @_;

    warn "# parseconfig ", $configfile if $debug;
    my %limits;

    local(*IN);
    open(IN, "<$configfile") or exit 4;

    my $name = undef;
    LINE: while(<IN>) {
	if(/subnet\s+((?:\d+\.){3}\d+)\s+netmask\s+((?:\d+\.){3}\d+)/ && ! /^\s*#/) {
	    $name = "$1 $2";
	    print "# DEBUG: Found a subnet: $name\n" if $debug;
	    $stat->{subnet}->{$1} = $2;
	    push @netmasks, Net::Netmask->new( $1, $2 );
	}
	if($name && /^\}$/) {
            if(!exists $limits{$name}) {
                print "# DEBUG: End of subnet... NO RANGE?\n" if $debug;
            }
	    $name = "";
	}
	if($name && /range\s+((?:\d+\.){3}\d+)\s+((?:\d+\.){3}\d+)/) {
	    print "# DEBUG: range $1 -> $2\n" if $debug;
	    $limits{$name} += &rangecount($1, $2);
	    print "# DEBUG: limit for $name is " . $limits{$name} . "\n" if $debug;
	}
	if(/^include \"([^\"]+)\";/) {
	    my $includefile = $1;
	    print "# DEBUG: found included file: $includefile\n" if $debug;
	    if(!-f $includefile) {
		$includefile = dirname($CONFIGFILE) . "/" . $includefile;
		if(!-f $includefile) {
		    next LINE;
		}
	    }
	    parseconfig($includefile);
	}
    }
    close(IN);
}

warn "# netmasks ", dump( \@netmasks ) if $debug;

sub rangecount {
    my ($from, $to) = @_;

    $from = ((new Net::IP($from))->intip())->numify();
    $to   = ((new Net::IP($to))->intip())->numify();
    
    if($from < $to) {
	return ($to - $from) + 1;
    } else {
	return ($from - $to) + 1;
    }
}



my $lease = parse_leases( '/var/lib/dhcp/dhcpd.leases' );

foreach my $ip ( sort keys %$lease ) {
	my $data = $lease->{$ip};

	$stat->{ $data->{'binding state'} }++;
	foreach my $netmask ( @netmasks ) {
		if ( $netmask->match( $ip ) ) {
			$stat->{ 'ips2' }->{$netmask}->{ $data->{'binding state'} }++;
			$stat->{ 'ips2' }->{$netmask}->{ _total }++;
		}
	}

	my $ip_24 = $ip; $ip_24 =~ s/\.\d+$//;
	$stat->{ 'ips' }->{$ip_24}->{ $data->{'binding state'} }++;
	$stat->{ 'ips' }->{$ip_24}->{ _total }++;

	next if ( ! $long && ! $all && $data->{'binding state'} ne 'active' ); # FIXME
	warn "# ",dump($data) if $debug;
	my $starts_t = str2time $data->{'starts'};
	my $ends_t = str2time $data->{'ends'};
	my $d_t = $ends_t ? $ends_t - $starts_t : -1;
	$data->{d_t} = $d_t;
	print "XX lease time $d_t ",dump($data) if $long && $d_t > 600;
	print join(' ', map { defined $data->{$_} ? $data->{$_} : '?' } (
				'lease',
				'hardware ethernet',
				'binding state',
				'ends',
				'd_t',
				'client-hostname',
				'ddns-fwd-name',
				'ddns-rev-name',
	)), "\n";
}

print "# binding state = ",dump($stat);
