#!/bin/bash


usage() {
   echo "Usage: kerberos-setup.sh [COMMAND] [OPTIONS] [VALUE]"
   echo " -d|--domain		Domain name"
   echo " -h|--host		Hostname"
   echo " -i|--ip                Host IP"
   echo " -o|--cmd-option        Command options for add_principal (addprinc) [see kadmin man page]"
   echo " -s|--service-type      Service principal name account (SPN)"
   echo " --help                 Print help"
   echo ""
   echo "Example:"
   echo "Adding a single principal"
   echo "kerberos-setup.sh -h web-server -i 192.168.0.100 -d web.example.com -o -randkey -s nfs"
   echo ""
   echo "Multiple SPN's can be added at the same time"
   echo "kerberos-setup.sh -h file01 -i 192.168.0.10 -o -randkey -h web01 -i 192.168.0.15 -o -randkey -d home.local"
   exit 0
}

abnormal_exit() {
   echo "Error: $1"
   exit 1
}

check_privilege() {
   local _user=$(whoami)

   [ $_user != "root" ] && abnormal_exit "Permission Denied"
}

add_host() {
   echo "Adding host to /etc/hosts ..."

   local _domain=$(echo $DOMAIN | tr [:upper:] [:lower:])

   for i in "${!HOSTS[@]}"; do
      
      local _exists=""
      _exists=$(cat /etc/hosts | grep ${IP[$i]}) 
       
      if [ ! "$_exists" ] && [ "${IP[$i]}" != "0" ]; then      
         echo "${IP[$i]}   ${HOSTS[$i]}.$_domain   ${HOSTS[$i]}" >> /etc/hosts
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
   sed -i "s/EXAMPLE.COM = {/$DOMAIN = {/" /var/kerberos/krb5kdc/kdc.conf
   echo "*/admin@$DOMAIN     *" > /var/kerberos/krb5kdc/kadm5.acl
}

start_service() {
  # TODO: ENSURE SERVICES ARE INSTALLED
  echo "Enabling systemd services ..."
  systemctl enable --now krb5kdc kadmin chronyd
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
   kadmin.local -q "addprinc zilencer/admin"
   
   echo "Adding service principal name (SPN) account to keytab ..."
   local _domain=$(echo $DOMAIN | tr [:upper:] [:lower:])

   for i in "${!HOSTS[@]}"; do
      kadmin.local -q "addprinc ${OPTION[$i]} ${SERVICE_TYPE[$i]}/${HOSTS[$i]}.$_domain"
   done
}

keytab_add() {
   echo "Adding principals that are authorized to use Kerberos authentication"

   local _domain=$(echo $DOMAIN | tr [:upper:] [:lower:])

   for i in "${!HOSTS[@]}"; do
      kadmin.local -q "ktadd ${SERVICE_TYPE[$i]}/${HOSTS[$i]}.$_domain"
   done
}

setup_kdc() {
   echo "Creating kerberos database ... "
   kdb5_util create -s
   start_service
   add_principal
   keytab_add
}

get_params() {

   while (($#))
   do
      case $1 in
         -h|--host)
	    HOSTS+=($2)
	    shift 2
	    ;;
          -i|--ip)
	    IP+=($2)
	    shift 2
	    ;; 
          -d|--domain)
	    DOMAIN=$(echo $2 | tr [:lower:] [:upper:])
	    shift 2
	    ;;
	  -o|--cmd-option)
	     OPTION+=($2)
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
          *)
	    echo "Invalid argument"
  	    ;;
      esac
   done
}

main() {
   check_privilege
   get_params $@
   add_host
   edit_config
   setup_kdc
}

main $@

