#!/bin/sh -xe

cat << __EOF__ | sudo nsupdate -l -k /etc/bind/ddns.key
update delete $1 A
update delete $1 TXT
send
__EOF__
