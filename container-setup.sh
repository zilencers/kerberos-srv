#!/bin/bash

SUBNET="192.168.20.0/24"
GATEWAY="192.168.20.1"
IP="192.168.20.253/32"
IP_ADDR="192.168.20.25"
INTERFACE="enp0s25"

abnormal_exit() {
    echo "Error: $1"
    exit 1
}

[ $(whoami) != "root" ] && abnormal_exit "Permission Denied"

printf "Building podman image ..."
if [[ ! $(podman images | grep -o krb5-srv) ]]; then
   podman build -q -t krb5-srv .
else
   printf "exists, skipping\n" 
fi

printf "Creating podman network ..."
if [[ ! $(podman network ls | grep -i local-lan) ]]; then
   podman network create \
      -d ipvlan \
      --subnet $SUBNET \
      --gateway $GATEWAY \
      --ip-range $IP \
      -o parent=$INTERFACE \
      --ignore \
      local-lan
else
   printf "exists, skipping\n"
fi

printf "Creating podman container ..." 
if [[ ! $(podman ps -a | grep -o kdc) ]]; then
   podman run -d -q \
     --ip $IP_ADDR \
     --name kdc \
     --hostname kerberos \
     --network local-lan \
     localhost/krb5-srv
elif [[ ! $(podman ps | grep -i kdc) ]]; then
   podman start kdc
   printf "exists, starting\n"
fi

podman exec -it kdc \
   usr/local/bin/krb5-kdc.sh \
   -h kerberos -i $IP_ADDR -s host \
   -h media-srv -i 192.168.20.10 -s nfs \
   -h file-srv -i 192.168.20.11 -s nfs \
   -d HOME.LOCAL

