#!/bin/sh
apt-get -y update
apt-get -y install python3
sudo apt -y install awscli
aws s3 cp s3://${bucket_name}/${k3s} .
aws s3 cp s3://${bucket_name}/${osquery} .
chmod +x ${k3s} & chmod +x ${osquery}
./${k3s} server & sleep 30
dpkg -i ${osquery}
mv k3s /home/ubuntu
cd /home/ubuntu
