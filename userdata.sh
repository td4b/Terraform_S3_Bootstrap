#!/bin/sh
apt-get -y update
apt-get -y install python3
sudo apt -y install awscli
aws s3 cp s3://${bucket_name}/${key} .
chmod +x ${key}
./${key} server & sleep 30
mv k3s /home/ubuntu
cd /var/lib/rancher/k3s/server/manifests
curl -LO https://k8s.io/examples/application/wordpress/mysql-deployment.yaml
curl -LO https://k8s.io/examples/application/wordpress/wordpress-deployment.yaml
cd /home/ubuntu
./k3s kubectl create -f /var/lib/rancher/k3s/server/manifests/mysql-deployment.yaml
./k3s kubectl create -f /var/lib/rancher/k3s/server/manifests/wordpress-deployment.yaml
