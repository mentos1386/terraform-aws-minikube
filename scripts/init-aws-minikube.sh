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
mkdir -p /etc/docker/ssl
docker run --rm -v /etc/docker/ssl:/certs \
  -e SSL_SUBJECT=$DNS_NAME \
  -e SSL_DNS=docker.local,$DNS_NAME,$FULL_HOSTNAME \
  -e SSL_IP=127.0.0.1,$IP_ADDRESS \
  -e SSL_EXPIRE="365" \
  paulczar/omgwtfssl
chmod +r /etc/docker/ssl/key.pem
## Modify daemon.json to listen on 2376 and use key/certs
cat > /etc/docker/daemon.json <<EOF
{
"hosts": ["fd://", "tcp://0.0.0.0:2376"],
"tlscacert": "/etc/docker/ssl/ca.pem",
"tlscert": "/etc/docker/ssl/cert.pem",
"tlskey": "/etc/docker/ssl/key.pem",
"tlsverify": true
}
EOF
# Remove hosts line from docker.service as it is now defined in daemon.json
sed -i -e 's|-H fd://||g' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker

# Add user to docker
usermod -aG docker ubuntu

# Install kubectl
snap install kubectl --classic

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
    --vm-driver=none \
    --kubernetes-version=$KUBERNETES_VERSION \
    --extra-config=apiserver.service-node-port-range=80-30000

chown -R ubuntu:ubuntu /home/ubuntu/.kube
chown -R ubuntu:ubuntu /home/ubuntu/.minikube

# Load addons
for ADDON in $ADDONS
do
  minikube addons enable $ADDON
done

# Create kubectl proxy that forwards API calls to minikube cluster API server
cat > /etc/systemd/system/kubectl-proxy.service <<EOF
[Unit]
Description=Kubectl Proxy
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/snap/bin/kubectl proxy --address=0.0.0.0 --accept-hosts=".*" --port 6443
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable kubectl-proxy
systemctl start kubectl-proxy
