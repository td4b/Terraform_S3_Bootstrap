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
wget https://dl.kolide.co/bin/fleet_latest.zip
unzip fleet_latest.zip 'linux/*' -d fleet
sudo cp fleet/linux/fleet /usr/bin/fleet
sudo cp fleet/linux/fleetctl /usr/bin/fleetctl
sudo apt-get install mysql-server -y
sudo apt-get install redis-server -y
