FROM quay.io/fedora/fedora:38-x86_64
COPY krb5-kdc.sh /usr/local/bin/krb5-kdc.sh 
RUN dnf -y install tzdata krb5-server krb5-workstation pam_krb5 \
&& ln -fs /usr/share/zoneinfo/America/Chicago /etc/localtime
CMD ["/usr/sbin/init"]

