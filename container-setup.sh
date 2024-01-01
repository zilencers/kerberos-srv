#!/bin/bash

SUBNET="192.168.20.0/24"
GATEWAY="192.168.20.1"
IP="192.168.20.253/32"
IP_ADDR="192.168.20.25"
INTERFACE="wlp3s0"   # "enp3s0"


printf "Building podman image ...\n"
if [[ ! $(podman images | grep -o krb5-srv) ]]; then
   podman build -q -t krb5-srv .
   printf "Done\n" 
else
   printf "exists, skipping\n" 
fi

echo "Creating podman network ..."
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

printf "Creating podman container ...\n" 
if [[ ! $(podman ps -a | grep -o kdc) ]]; then
   podman run -d -q \
      --ip $IP_ADDR\
      --name kdc \
      --hostname kdc \
      --network local-lan \
      localhost/krb5-srv

   printf "Done\n" 
elif [[ ! $(podman ps | grep -i kdc) ]]; then
   podman start kdc
   printf "exists, starting\n"
fi

podman exec -it kdc \
   usr/local/bin/krb5-kdc.sh \
   -h kdc -i 0 -s host \
   -h media-srv -i 192.168.20.10 -s nfs \
   -h file-srv -i 192.168.20.11 -s nfs \
   -d HOME.LOCAL

