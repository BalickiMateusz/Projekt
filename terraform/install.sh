#!/bin/bash
yum update -y
yum install -y yum-utils device-mapper-persistent-data lvm2 python3-pip git docker

systemctl start docker
systemctl enable docker

if [ ! -f "/usr/local/bin/docker-compose" ]; then
    wget -q https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -O /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

git clone https://github.com/BalickiMateusz/Projekt.git /home/ec2-user/Projekt

echo -e "\nREACT_APP_SERVER_URL=$(curl checkip.amazonaws.com)" | sudo tee -a /home/ec2-user/Projekt/client/.env > /dev/null

sudo docker-compose -f /home/ec2-user/Projekt/docker-compose.yml up -d