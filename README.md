# bind command examples

## check bind config

/usr/sbin/named-checkconf /etc/bind/named.conf.local

## check zone file

/usr/sbin/named-checkzone ffzg.hr /etc/bind/hosts.db

/usr/sbin/named-checkzone 212.198.193.in-addr.arpa /etc/bind/hosts.rev212


# tools to check bind

Install prerequisite perl modules

sudo apt install libdata-dump-perl libparse-recdescent-perl libnet-subnet-perl

All commands assume that you are running them with user which has
privileges to read key files (using sudo -u bind command).

## lint all bind zones

./bind-lint.pl

## dump parsed bind config

./bind-config.pl

## dump original config with parsed one

DEBUG=1 ./bind-config.pl 2>&1 | less

## debug bind parser

DEBUG=2 ./bind-config.pl 2>&1 | less


# cleanup static mapping file

## forward

This assumes that you have a list of free IPs which you want to remove

./zone-comment.pl /etc/bind/hosts.db ~dpavlin/ips/ips.free > /tmp/zone.comment
vi /etc/bind/hosts.db /tmp/zone.comment -d

## reverse

This assumes that your forward mapping is correct and you want to fix
reverse mapping to match it. It only includes A records in reverse
mapping, not CNAMEs.

run ./zone-forward-reverse.pl to generate reverse mappings which are extra in
file /tmp/zone.extra.ptr

# ./zone-comment.pl /etc/bind/hosts.rev212 /tmp/zone.extra.ptr > /tmp/hosts.rev212
## compare forward and reverse mappings



## cleanup extra dynamic mappings

After running ./zone-forward-reverse.pl use /tmp/nsupdate.delete to remove
extra dynamic mappings using nsupdate

./nsupdate-delete.pl /tmp/nsupdate.delete | nsupdate -v -d && /usr/sbin/rndc sync -clean

## generate one file per zone for update

FILE=1 ./nsupdate-delete.pl /tmp/nsupdate.delete


