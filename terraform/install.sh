#!/bin/bash

sudo yum update

sudo yum install -y docker
sudo yum install -y git

systemctl start docker
systemctl enable docker

sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

git clone https://github.com/BalickiMateusz/Projekt.git /home/ec2-user/Projekt

echo -e "\nREACT_APP_SERVER_URL=$(curl checkip.amazonaws.com)" | sudo tee -a /home/ec2-user/Projekt/client/.env > /dev/null
echo -e "\nCLIENT_URL=$(curl checkip.amazonaws.com)" | sudo tee -a /home/ec2-user/Projekt/server/.env > /dev/null

sudo docker-compose -f /home/ec2-user/Projekt/docker-compose.yml up -d