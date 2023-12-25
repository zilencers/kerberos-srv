FROM quay.io/fedora/fedora:38-x86_64
RUN dnf -y install git chrony krb5-server krb5-workstation pam_krb5
CMD ["/usr/sbin/init"]

