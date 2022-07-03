#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use lib './lib';
use BIND::Config qw( check_config @zones );
use DHCPD::Leases qw(parse_leases);

use Data::Dump qw(dump);

my $debug = $ENV{DEBUG} || 0;

$|=1 if $debug;

my $zone;
my $stat;

my $origin;
my $name;
sub full_name {
	my $full_name = shift;
	return lc($full_name) if $full_name =~ m/\.$/;
	$full_name .= '.';
	$full_name .= $origin if defined $origin;
	$full_name =~ s/\.\.+$/\./;
	$full_name .= '.' unless $full_name =~ m/\.$/;
	$full_name =~ s/^\@\.//;
	return lc($full_name);
}

check_config( $ARGV[0] || "/etc/bind/named.conf" );


my $lease = parse_leases( '/var/lib/dhcp/dhcpd.leases' );
warn "# lease = ",dump( $lease ) if $debug > 3;

my $dynamic_regex = '(' . join('|', keys %{ $BIND::Config::allow_update } ) . ')\.?';
warn "# dynamic_regex = $dynamic_regex\n" if $debug;
my $zone_in_file; 

warn "# zones = ",dump( \@zones );

foreach my $zone_name_file ( @zones ) {

	my ( $zone_name, $zone_file ) = @$zone_name_file;

	$zone_in_file->{$zone_name} = $zone_file;
	$origin = $zone_name;

	open(my $fh, '<', $zone_file);
	while(<$fh>) {
		chomp;
		print "# $zone_file: $_\n" if $debug;
		if ( m/^\s*;/ || m/^$/ ) {
			next;
		} elsif ( m/^\s*\$ORIGIN\s(\S+)/ ) {
			$origin = $1;
		} elsif ( m/^(\S+)\s/ ) {
			$name = full_name( $1 );
		}
		
		if ( m/\s(A|CNAME|PTR)\s+(\S+)/ ) {
			my ($in,$v) = ($1,$2);
			if ( $name !~ m/^\@/ ) { # skip SOA
				push @{ $zone->{uc($in)}->{ $name } }, $in eq 'A' ? $v : full_name( $v );
				print "++ $name $in $v\n" if $debug;
				if ( $in eq 'A' ) {
					push @{ $zone->{_ip2name}->{ $name =~ m/$dynamic_regex/ ? 'dhcp' : 'static' }->{$v} }, $name;
				}
			}
		} elsif ( m/\s(NS)\s+(\S+)/ ) {
			push @{ $zone->{_subdomain_ns}->{$name} }, $2;
		}
	}

}

# remove local zones
my @local_zones;
foreach my $zone_file ( @zones ) {
	my ( $zone_dot, undef ) = @$zone_file;
	$zone_dot .= '.' unless $zone_dot =~ m/\.$/;
	if ( exists $zone->{_subdomain_ns}->{ $zone_dot } ) {
		delete $zone->{_subdomain_ns}->{ $zone_dot };
		push @{ $zone->{_local_zones} }, $zone_dot;
	}
}
delete $zone->{_subdomain_ns}->{ '' }; # localhost.

warn "# zone = ",dump( $zone ) if $debug;

my $local_zone_regex    = '(' . join('|',      @{ $zone->{_local_zones} }  ) . ')$';
my $external_zone_regex = '(' . join('|', keys %{ $zone->{_subdomain_ns} } ) . ')$';
$local_zone_regex =~ s/\./\\./g;
$external_zone_regex =~ s/\./\\./g;

$external_zone_regex = undef if $external_zone_regex eq '()$'; # cleanup if empty

warn "# local_zone_regex=$local_zone_regex\n# external_zone_regex=$external_zone_regex\n" if $debug;

my @nsupdate_delete;
my $zone_missing_ptr;

foreach my $name ( sort keys %{ $zone->{A} } ) {

	next if $name eq '' || $name =~ m/^localhost/; # localhost.

	foreach my $ip ( @{ $zone->{A}->{$name} } ) {
		my $ptr = join('.', reverse split(/\./,$ip)) . '.in-addr.arpa.';

		if ( $name =~ m/$dynamic_regex/ ) {
			$stat->{dynamic}->{count}++;
			if ( exists $lease->{$ip} ) {

				my $lease_state = $lease->{$ip}->{'binding state'} || die "no binding state";
				$stat->{dynamic}->{state}->{ $lease_state }++;

				if ( $lease_state eq 'active' ) {
					if ( ! exists $lease->{$ip}->{'ddns-fwd-name'} ) {
						# no name in lease file
						print "DYNAMIC OK $name A $ip (missing ddns-fwd-name)\n";
						$stat->{dynamic}->{ok_no_ddns}->{a}++;
					} else {
						my $ddns = lc( $lease->{$ip}->{'ddns-fwd-name'} ) . '.';
						if ( $ddns eq $name ) {
							print "DYNAMIC OK $name A $ip\n";
							$stat->{dynamic}->{ok}->{a}++;
						} else {
							print "DYNAMIC WRONG NAME $name != $ddns A $ip\n";
							$stat->{dynamic}->{wrong}->{a}++;
							push @nsupdate_delete,$name;
						}
					}

					if ( exists $zone->{PTR}->{$ptr} ) {
						print "DYNAMIC EXISTS $name PTR $ptr\n";
						$stat->{dynamic}->{exists}->{ptr}++;

=for later
						my $rddns = lc( $lease->{$ip}->{'ddns-rev-name'} );
						foreach my $rname ( @{ $zone->{PTR}->{$ptr} } ) {
							if ( $rname eq $rddns ) {	
								print "DYNAMIC OK $rname PTR $ptr\n";
								$stat->{dynamic}->{ok}->{ptr}++;
							} else {
								print "DYNAMIC EXTRA $rname != $rddns PTR $ptr\n";
								$stat->{dynamic}->{extra}->{ptr}++;
							}
						}
=cut
					} else {
						print "DYNAMIC MISSING $name PTR $ptr\n";
						$stat->{dynamic}->{missing}->{ptr}++;
					}
				} else {
					print "DYNAMIC EXTRA $name A $ip (lease state: $lease_state)\n";
					$stat->{dynamic}->{extra}->{$lease_state}->{a}++;
					push @nsupdate_delete,$name;

					if ( exists $zone->{PTR}->{$ptr} ) {
						print "DYNAMIC EXTRA $name PTR $ptr\n";
						$stat->{dynamic}->{extra}->{$lease_state}->{ptr}++;
						push @nsupdate_delete,$ptr;
					}
				}
			} else {
				print "DYNAMIC EXTRA $name A $ip\n";
				$stat->{dynamic}->{extra}->{a}++;
				push @nsupdate_delete,$name;
				if ( exists $zone->{PTR}->{$ptr} ) {
					print "DYNAMIC EXTRA $name PTR $ptr\n";
					$stat->{dynamic}->{extra}->{ptr}++;
					push @nsupdate_delete,$ptr;
				}
			}

		} elsif ( exists $zone->{PTR}->{$ptr} ) { # check reverse for name for static IPs
			foreach my $rname ( @{ $zone->{PTR}->{$ptr} } ) {
				if ( $rname eq $name ) {
					print "OK $name $ip has $ptr\n";
					$stat->{ok}->{ptr}++;
				} else {
					print "ADDITIONAL $ptr IN PTR $rname != $name\n";
					$stat->{additional}->{ptr}++;
				}
			}
		} else {
			print "MISSING $ptr IN PTR $name\n";
			$stat->{missing}->{ptr}++;
			push @{ $zone_missing_ptr->{$ptr} }, $name
		}
	}
}

warn "# zone_missing_ptr = ",dump( $zone_missing_ptr ) if $debug;

# FIXME check all ips from $lease, not only in zone files

foreach my $name ( sort keys %{ $zone->{CNAME} } ) {
	foreach my $t ( @{ $zone->{CNAME}->{$name} } ) {
		if ( exists $zone->{A}->{$t} ) {
			print "OK CNAME $name -> A $t\n";
			$stat->{ok}->{cname_a}++;
		} elsif ( exists $zone->{CNAME}->{$t} ) {
			print "OK CNAME $name -> CNAME $t\n";
			$stat->{ok}->{cname_cname}++;
		} else {
			print "CNAME $name MISSING $t\n";
			$stat->{missing}->{cname}++;
		}
	}
}

my @extra;

foreach my $ptr ( sort keys %{ $zone->{PTR} } ) {

	foreach my $name ( @{ $zone->{PTR}->{$ptr} } ) {
		next if $name eq 'localhost.';

		if ( $external_zone_regex && $name =~ m/$external_zone_regex/ || $name !~ m/$local_zone_regex/ ) {
			print "EXTERNAL PTR $name\n";
			push @{ $stat->{external_ptr} }, $name;
			next;
		}

		if ( exists $zone->{A}->{$name} ) {
			print "OK PTR $ptr -> A $name\n";
			$stat->{ok}->{ptr_a}++;
		} elsif ( exists $zone->{CNAME}->{$name} ) {
			print "OK PTR $ptr -> CNAME $name\n";
			$stat->{ok}->{ptr_cptr}++;
		} else {
			print "PTR $ptr EXTRA $name\n";
			$stat->{extra}->{ptr}++;
			push @extra, $ptr;
		}
	}
}

print "# stat = ",dump($stat), "\n";

open(my $fh, '>', '/tmp/nsupdate.delete');
print $fh "$_\n" foreach @nsupdate_delete;
close($fh);

print "# created /tmp/nsupdate.delete ", -s "/tmp/nsupdate.delete", " bytes\n";

my $zone_regex = '(' . join('|', keys %$zone_in_file) . ')';
my $zone_extra_ptr;

open(my $fh, '>', '/tmp/zone.extra.ptr');
foreach my $ptr ( @extra ) {
	if ( $ptr =~ m/$zone_regex/ ) {
		push @{ $zone_extra_ptr->{$1} }, $ptr;
	} else {
		die "can't find zone for $ptr";
	}
	print $fh "$ptr\n";
}
close($fh);

warn "# zone_extra_ptr = ",dump( $zone_extra_ptr ), "\n" if $debug;

print "# created /tmp/zone.extra.ptr ", -s "/tmp/zone.extra.ptr", " bytes\n";

my $dir = '/tmp/zone.commented';
mkdir $dir unless -e $dir;
foreach my $zone ( keys %$zone_extra_ptr ) {
	next if $zone =~ m/$dynamic_regex/; # take only static zones
	my $in = $zone_in_file->{$zone};
	my $out = $in;
	$out =~ s{^.*/([^/]+)$}{$dir/$1};
	open(my $comment, '>', "$out.extra");
	foreach my $ptr ( @{ $zone_extra_ptr->{$zone} } ) {
		print $comment "$ptr\n";
	}
	close($comment);
	system "./zone-comment.pl $zone_in_file->{$zone} $out.extra > $out";
	print "# commented $in $out ", -s $out, " bytes\n";
}

my $file_missing_ptr = '/tmp/zone.missing.ptr';
my $zone_missing_ptr_by_zone;
foreach my $ptr ( sort keys %{ $zone_missing_ptr } ) {
	my @names = @{ $zone_missing_ptr->{$ptr} };
	if ( $ptr =~ m/$zone_regex/ ) {
		my $zone = $1;
		foreach my $name ( @names ) {
			push @{ $zone_missing_ptr_by_zone->{$zone} }, "$ptr\tIN\tPTR\t$name";
		}
	} else {
		warn "# SKIP PTR $ptr @names not in our zone\n" if $debug;
	}
}
open(my $fh, '>', $file_missing_ptr );
foreach my $zone ( keys %{ $zone_missing_ptr_by_zone } ) {
	print $fh "; insert into ", $zone_in_file->{$zone}, "\n";
	foreach my $ptr ( @{ $zone_missing_ptr_by_zone->{$zone} } ) {
		print $fh "$ptr\n";
	}
}
close($fh);

print "# created $file_missing_ptr ", -s $file_missing_ptr, " bytes\n";

# dump static IP addresses
open(my $ips, '>', '/tmp/zone.ips.static');
print $ips join("\n", keys %{ $zone->{_ip2name}->{static} } );
close($ips);

print "# created /tmp/zone.ips.static ", -s "/tmp/zone.ips.static", " bytes\n";

