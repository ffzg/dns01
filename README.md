# bind command examples

## check bind config

/usr/sbin/named-checkconf /etc/bind/named.conf.local

## check zone file

/usr/sbin/named-checkzone ffzg.hr /etc/bind/hosts.db

/usr/sbin/named-checkzone 212.198.193.in-addr.arpa /etc/bind/hosts.rev212


# tools to check bind

sudo apt install libdata-dump-perl libparse-recdescent-perl libnet-subnet-perl

## lint all bind zones

sudo -u bind ./bind-lint.pl

## dump parsed bind config

sudo -u bind ./bind-config.pl

## dump original config with parsed one

sudo -u bind DEBUG=1 ./bind-config.pl 2>&1 | less

## debug bind parser

sudo -u bind DEBUG=2 ./bind-config.pl 2>&1 | less

## compare forward and reverse mappings

sudo -u bind ./zone-forward-reverse.pl

## delete extra dynamic mappings

./nsupdate-delete.pl /tmp/nsupdate.delete | nsupdate -v -d && /usr/sbin/rndc sync -clean

## generate one file per zone for update

FILE=1 ./nsupdate-delete.pl /tmp/nsupdate.delete


# cleanup static hosts file

## forward

This assumes that you have a list of free IPs which you want to remove

./zone-comment.pl /etc/bind/hosts.db ~dpavlin/ips/ips.free > /tmp/zone.comment
vi /etc/bind/hosts.db /tmp/zone.comment -d

## reverse

run ./zone-forward-reverse.pl to generate reverse mappings which are extra in
file /tmp/zone.extra.ptr

# ./zone-comment.pl /etc/bind/hosts.rev212 /tmp/zone.extra.ptr > /tmp/hosts.rev212
