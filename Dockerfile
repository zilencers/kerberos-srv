FROM quay.io/fedora/fedora:38-x86_64
COPY krb5-kdc.sh /usr/local/bin/krb5-kdc.sh 
RUN dnf -y install chrony krb5-server krb5-workstation pam_krb5
CMD ["/usr/sbin/init"]
