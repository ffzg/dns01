# check bind config

/usr/sbin/named-checkconf /etc/bind/named.conf.local

# check zone file

/usr/sbin/named-checkzone ffzg.hr /etc/bind/hosts.db

/usr/sbin/named-checkzone 212.198.193.in-addr.arpa /etc/bind/hosts.rev212

# lint all bind zones

sudo -u bind ./bind-lint.pl
