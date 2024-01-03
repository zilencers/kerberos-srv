FROM quay.io/fedora/fedora:38-x86_64
RUN dnf -y install tzdata krb5-server krb5-libs krb5-workstation pam_krb5 \
&& ln -fs /usr/share/zoneinfo/America/Chicago /etc/localtime
COPY hosts /etc/hosts 
COPY ../krb5-kdc.sh /usr/local/bin/krb5-kdc.sh
CMD ["/usr/sbin/init"]
