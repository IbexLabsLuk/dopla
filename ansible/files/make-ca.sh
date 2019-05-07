#!/bin/bash
MASTER_IP=$1
CN_NAME=$2
LOCAL_CN_NAME=$3
cert_dir=/etc/kubernetes/certs

# Download and create keystore
cd /tmp
curl -L -O https://storage.googleapis.com/kubernetes-release/easy-rsa/easy-rsa.tar.gz
tar xfz easy-rsa.tar.gz
cp -a /tmp/easy-rsa-master/easyrsa3 ~/dopla-ca-pki
rm -rf /tmp/easy-rsa*

# Init PKI
echo "Initializing PKI"
cd ~/dopla-ca-pki/
./easyrsa init-pki
echo "Creating CA-Cert"
./easyrsa --batch "--req-cn=${LOCAL_CN_NAME}" build-ca nopass
./easyrsa --subject-alt-name="IP:${MASTER_IP},DNS:${CN_NAME},DNS:${LOCAL_CN_NAME}" build-server-full master nopass
./easyrsa --subject-alt-name="IP:${MASTER_IP},DNS:${CN_NAME},DNS:${LOCAL_CN_NAME}" build-client-full kubecfg nopass
./easyrsa --subject-alt-name="IP:${MASTER_IP},DNS:${CN_NAME},DNS:${LOCAL_CN_NAME}" build-client-full kubelet nopass

cp -p pki/ca.crt "${cert_dir}/ca.crt"
cp -p pki/issued/master.crt "${cert_dir}/server.crt"
cp -p pki/private/master.key "${cert_dir}/server.key"
cp -p pki/issued/kubecfg.crt "${cert_dir}/kubecfg.crt"
cp -p pki/private/kubecfg.key "${cert_dir}/kubecfg.key"
cp -p pki/issued/kubelet.crt "${cert_dir}/kubelet.crt"
cp -p pki/private/kubelet.key "${cert_dir}/kubelet.key"