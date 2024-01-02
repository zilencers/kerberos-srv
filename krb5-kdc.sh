#!/bin/bash

usage() {
   echo "Usage: krb5-setup.sh [COMMAND] [OPTIONS] [VALUE]"
   echo " -d|--domain           Domain name"
   echo " -h|--host             Hostname"
   echo " -i|--ip                Host IP"
   echo " -s|--service-type      Service principal name account (SPN)"
   echo " --help                 Print help"
   echo ""
   echo "Example:"
   echo "Adding a single principal"
   echo "krb5-setup.sh \"-h web-server -i 192.168.0.100 -d web.example.com -o -randkey -s nfs\""
   echo ""
   echo "Multiple SPN's can be added at the same time"
   echo "krb5-setup.sh -h file01 -i 192.168.0.10 -o -randkey -h web01 -i 192.168.0.15 -o -randkey -d home.local"
   exit 0
}

abnormal_exit() {
   echo "Error: $1"
   exit 1
}

is_root() {
   local _user=$(whoami)
   [ $_user != "root" ] && abnormal_exit "Permission Denied"
}

add_host() {
   # Kerberos requires at least a basic schema of name resolution and the 
   # Network Time Protocol service to be present in both client and server 
   # since the security of Kerberos authentication is in part based upon 
   # the timestamps of tickets.

   echo "Adding host to /etc/hosts ..."

   for i in "${!HOST[@]}"; do
      if [[ "${IP[$i]}" != "0" ]]; then 
         echo "${IP[$i]}   ${HOST[$i]}.$(echo $DOMAIN | tr [:upper:] [:lower:])   ${HOST[$i]}" >> /etc/hosts
      fi
   done
}

edit_config() {
   echo "Adding $DOMAIN to /etc/krb5.conf ..."

   local _domain=$(echo $DOMAIN | tr [:upper:] [:lower:])

   sed -i "s/#    default_realm = EXAMPLE.COM/    default_realm = $DOMAIN/" /etc/krb5.conf
   sed -i "s/# EXAMPLE.COM = {/ $DOMAIN = {/" /etc/krb5.conf
   sed -i "s/#     kdc = kerberos.example.com/     kdc = kerberos.$_domain/" /etc/krb5.conf
   sed -i "s/#     admin_server = kerberos.example.com/     admin_server = kerberos.$_domain/" /etc/krb5.conf
   sed -i 's/# }/ }/' /etc/krb5.conf
   sed -i "s/# .example.com = EXAMPLE.COM/ .$_domain = $DOMAIN/" /etc/krb5.conf
   sed -i "s/# example.com = EXAMPLE.COM/ $_domain = $DOMAIN/" /etc/krb5.conf
   sed -i "s/default_ccache_name = KEYRING:persistent:%{uid}/#   default_ccache_name = KEYRING:persistent:%{uid}/" /etc/krb5.conf
   sed -i "s/EXAMPLE.COM = {/$DOMAIN = {/" /var/kerberos/krb5kdc/kdc.conf
   echo "*/admin@$DOMAIN     *" > /var/kerberos/krb5kdc/kadm5.acl
}

validate_args() {
   [ ! "$DOMAIN" ] && abnormal_exit "Missing required argument: -d|--domain"
   [ ! "$HOST" ] && abnormal_exit "Missing required argument: -h|--host"
   [ ! "$IP" ] && abnormal_exit "Missing required argument: -i|--ip"
   [ ! "$SERVICE_TYPE" ] && abnormal_exit "Missing required argument: -s|--service-type"
}

start_service() {
  echo "Enabling systemd services ..."
  systemctl enable --now krb5kdc
  systemctl enable --now kadmin
}

add_principal() {   
   # A service principal name (SPN) account uniquely identifies an instance of a service. 
   # Before the Kerberos authentication service can use an SPN to authenticate a service, 
   # you must register the SPN
   # An SPN consists of the following information:
   #   * Service type: Specifies the protocol to use, such as HTTP
   #   * Instance: Specifies the name of the server hosting the application. For example: finance1.us.example.com
   #   * Realm: Specifies the domain name of the server hosting the application. For example: US.EXAMPLE.COM

   echo "Adding admin principal for root ..."
   kadmin.local -q "addprinc root/admin"
   
   echo "Adding service principal name (SPN) account to keytab ..."

   for i in "${!HOSTS[@]}"; do
      kadmin.local "addprinc ${SERVICE_TYPE[$i]}/${HOSTS[$i]}.$(echo $DOMAIN | tr [:upper:] [:lower:])"
   done
}

keytab_add() {
   echo "Adding principals that are authorized to use Kerberos authentication"
   
   for i in "${!HOSTS[@]}"; do
      kadmin.local -q "ktadd ${SERVICE_TYPE[$i]}/${HOSTS[$i]}.$(echo $DOMAIN | tr [:upper:] [:lower:])"
   done
}

setup_kdc() {
   echo "Creating kerberos database ... "
   kdb5_util create -s
   start_service
   add_principal
   keytab_add
}

get_args() {
   while (($#))
   do
      case $1 in
         -h|--host)
	    HOST+=($2)
	    shift 2
	    ;;
          -i|--ip)
	    IP+=($2)
	    shift 2
	    ;; 
          -d|--domain)
	    DOMAIN=$2
	    shift 2
	    ;;
	  -s|--service-type)
	    SERVICE_TYPE+=($2)
	    shift 2
	    ;;
	  --help)
	    usage
	    shift 1
	    ;;
          -*|--*=) 
            abnormal_exit "Unsupported flag $1"
            ;;
      esac
   done
}

main() {
    get_args $@
    validate_args
    is_root
    add_host
    edit_config
    setup_kdc
}

main $@
