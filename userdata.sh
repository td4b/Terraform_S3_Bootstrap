#!/bin/sh
apt-get -y update
apt-get -y install python3
sudo apt -y install awscli
aws s3 cp s3://${bucket_name}/${key} .
chmod +x install.sh
./install.sh
