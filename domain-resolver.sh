#!/usr/bin/env bash
filename="$1"
while read -r line
do
        ddns_record="$line"
        if [[ !  -z  $ddns_record ]]; then
                resolved_ip=`getent ahosts $line | awk '{ print $1 ; exit }'`
                if [[ !  -z  $resolved_ip ]]; then
                        echo "allow $resolved_ip;# from $ddns_record"
                fi
        fi
done < "$filename"
