This journey started with me wanting to figure out which records
in our DNS are no longer used. In the process, I also discovered
that ISC dhcp server doesn't remove dynamic DNS entries from
bind, so this had to be handled with also.

# Which IPs are used on our network?

We have [zeek](https://zeek.org/) tracking our network traffic,
so it was somewhat easy to figure out which IPs are used inside
our network in last year (that is how much logs we have).

To do that, I used `bro-cut id.orig_h` to extract IPs originating
from our network and wrote [bro-ips.sh](https://github.com/ffzg/bro-tools/blob/master/bro-ips.sh)
which collect used ips by day into separate git repository
and generate summary of all used and unused ips.

# Remove unused static IP mappings from BIND

Once we had list of free IPs, I wanted to comment them out
in zone file. For this I wrote [zone-comment.pl](/zone-comment.pl)
which takes zone file and list of IPs and comments them out, so I can
compare zone files and if happy migrate them into zone file.

```
./zone-comment.pl /etc/bind/hosts.db ~dpavlin/ips/ips.free > /tmp/zone.comment
vi /etc/bind/hosts.db /tmp/zone.comment -d
```

# Check reverse zone files

Once we have cleanup up forward zone file, we need to also update reverse
mappings. For this, there is [zone-forward-reverse.pl](/zone-forward-reverse.pl)
which does a lot, so let's step through everything.

- read bind configuration and parse it
- read dhcpd leases file
- read zone files from bind
- check A records, splitting then into static and dynamic (from dhcpd)
- check CNAME records
- check PTR records
- generate `/tmp/nsupdate.delete` with dynamic records to delete with `nsupdate`
- generate `/tmp/zone.extra.ptr` with extra PTR records
- generate directory `/tmp/zone.commented` with commented zones based on data above
- generate `/tmp/zone.ips.static` with list of static IPs


