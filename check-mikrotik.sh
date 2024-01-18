#!/bin/sh -e

# wget http://standards-oui.ieee.org/oui.txt
# grep Routerboard oui.txt  | grep hex | cut -f1 | cut -d' ' -f1 | tr - : | tr '\n' '|'
regex='(08:55:31|B8:69:F4|00:0C:42|78:9A:18|DC:2C:6E|48:8F:5A|C4:AD:34|6C:3B:6B|D4:01:C3|48:A9:8A|2C:C8:1B|64:D1:54|E4:8D:8C|18:FD:74|4C:5E:0C|D4:CA:6D|74:4D:28|CC:2D:E0)'

# no args, less current
test -z "$1" && grep -i -E $regex /var/log/syslog | less

# with args, iterate over files
while [ -e "$1" ] ; do
	echo "# $1"
	zgrep -i -E $regex $1 | grep -v firewall
	shift
done

