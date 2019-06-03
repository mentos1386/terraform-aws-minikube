#!/bin/bash

exec &> /var/log/init-aws-minikube.log

set -o verbose
set -o errexit
set -o pipefail

export DNS_NAME=${dns_name}
export IP_ADDRESS=${ip_address}
export CLUSTER_NAME=${cluster_name}
export ADDONS="${addons}"
export KUBERNETES_VERSION="${kubernetes_version}"

# Set this only after setting the defaults
set -o nounset

# We needed to match the hostname expected by kubeadm an the hostname used by kubelet
FULL_HOSTNAME="$(curl -s http://169.254.169.254/latest/meta-data/hostname)"

# Make DNS lowercase
DNS_NAME=$(echo "$DNS_NAME" | tr 'A-Z' 'a-z')

export DEBIAN_FRONTEND=noninteractive

# Install Docker
apt update -y
apt install -y apt-transport-https ca-certificates curl gnupg software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update -y
apt install -y docker-ce
systemctl start docker
systemctl enable docker

# Generate SSL Certs for docker
## Certificate authority
 docker run --rm -v $(pwd)/.docker:/certs \
    -e SSL_SUBJECT="$DNS_NAME" \
    paulczar/omgwtfssl
cp $(pwd)/.docker/ca.pem /etc/docker/ssl/ca.pem
## Certificate and key
docker run --rm -v /etc/docker/ssl:/server \
    -e SSL_SUBJECT=$DNS_NAME \
    -e SSL_DNS=docker.local,$DNS_NAME,$FULL_HOSTNAME
    -e SSL_IP=127.0.0.1,$IP_ADDRESS \
    -e SSL_EXPIRE="365" \
    -e SSL_KEY=/server/key.pem \
    -e SSL_CERT=/server/cert.pem \
    paulczar/omgwtfssl
## Modify daemon.json to listen on 2376 and use key/certs
cat <<EOF
{
"hosts": ["fd://", "tcp://0.0.0.0:2376"],
"tlscacert": "/etc/docker/ssl/ca.pem",
"tlscert": "/etc/docker/ssl/cert.pem",
"tlskey": "/etc/docker/ssl/key.pem",
"tlsverify": true
}
EOF > /etc/docker/daemon.json
systemctl restart docker

# Add user to docker
usermod -aG docker ubuntu

# Install Minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
cp minikube /usr/local/bin && rm minikube

# Start minikube
export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export MINIKUBE_HOME=/home/ubuntu
export CHANGE_MINIKUBE_NONE_USER=true
export KUBECONFIG=/home/ubuntu/.kube/config
minikube start \
    -p $CLUSTER_NAME
    --vm-driver=none \
    --kubernetes-version=$KUBERNETES_VERSION \
    --extra-config=apiserver.service-node-port-range=80-443

# Load addons
for ADDON in $ADDONS
do
  minikube addons enable $ADDON
done
