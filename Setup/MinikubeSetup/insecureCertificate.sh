#!/bin/bash

echo "Start CA setup"

# Fix docker pull from VM and more
# https://stackoverflow.com/questions/50768317/docker-pull-certificate-signed-by-unknown-authority
openssl s_client -showcerts -connect registry-1.docker.io:443 < /dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/ca.crt

cat ~/ca.crt

sudo cp ~/ca.crt /usr/local/share/ca-certificates/

ls -a /usr/local/share/ca-certificates/

sudo update-ca-certificates

sudo systemctl restart docker.service

echo "Done"