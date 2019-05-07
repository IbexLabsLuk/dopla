#!/bin/bash
# Creates an admin user certificate to import into browsers / apps.
# $1 = The username.
USERNAME=$1

echo "Generating user ${USERNAME}"
openssl genrsa -out $USERNAME-key.pem 2048 
openssl req -new -key $USERNAME-key.pem -out $USERNAME.csr -subj "/CN=kube-admin"
openssl x509 -req -in $USERNAME.csr -CA ./pki/ca.crt -CAkey ./pki/ca.key -CAcreateserial -out $USERNAME.pem -days 365
openssl pkcs12 -export -in $USERNAME.pem -inkey $USERNAME-key.pem -out $USERNAME.p12