#!/usr/bin/env bash
allowed_hosts="/etc/nginx/allowedhosts.conf"
filename="$1"
updated=false
temp_file=$(mktemp)
while read -r line
do
        ddns_record="$line"
        if [[ !  -z  $ddns_record ]]; then
                resolved_ip=`getent ahosts $line | awk '{ print $1 ; exit }'`
                if ! grep -q $resolved_ip "$allowed_hosts"; then
                    updated=true
                fi
                if [[ !  -z  $resolved_ip ]]; then
                        echo "allow publish $resolved_ip; #from $ddns_record" >> $temp_file
                fi
        fi
done < "$filename"
if $updated; then
        cp -f $temp_file $allowed_hosts
        service nginx reload
fi
rm ${temp_file}
