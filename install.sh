#!/bin/sh
sudo apt-get -y update
sudo apt-get -y install docker.io
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
git clone https://github.com/mushorg/snare.git
cd snare
docker-compose build
docker-compose up -d
sleep 30
git clone https://github.com/zecure/packaging
cd packaging/docker/compose
sudo ./shadowdctl up -d
sleep 30
echo "Done Installing!"
echo "You need to add user to the web interface:"
echo "sudo ./shadowdctl exec web ./app/console swd:register --admin --name=arg (--email=arg)"
