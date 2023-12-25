#!/bin/bash

podman build -t kerberos-server .

podman run -it --name kdc kerberos-server /bin/bash

