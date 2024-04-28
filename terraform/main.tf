terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
    required_version = ">= 1.2.0"
}

provider "aws" {
    region = "us-east-1"
    profile = "default"
}

resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "VPC"
    }
}

resource "aws_subnet" "subnet-tic-tac-toe"{
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    tags = {
        Name = "Subnet tic-tac-toe"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
    tags = {
        Name = "Gateway"
    }
}

resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Route Table"
    }
}

resource "aws_route_table_association" "asc" {
    subnet_id = aws_subnet.subnet-tic-tac-toe.id
    route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "sg_tic_tac_toe" {
    vpc_id = aws_vpc.prod-vpc.id
    ingress {
        description = "Client"
        from_port = 3001
        to_port = 3001
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Server"
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
            description = "SSH"
            from_port = 22
            to_port = 22
            protocol = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }

    egress {
        description = "Outbound traffic rule"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "Security Group"
    }
}

resource "aws_network_interface" "web-server-nic" {
    subnet_id       = aws_subnet.subnet-tic-tac-toe.id
    private_ips     = ["10.0.1.50"]
    security_groups = [aws_security_group.sg_tic_tac_toe.id]

}

resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.gw]
}

resource "aws_key_pair" "deployer" {
    key_name   = "main-key"
    public_key = "${file("id_rsa.pub")}"
}

resource "aws_instance" "ec2-instance" {
    ami = "ami-04e5276ebb8451442"
    instance_type = "t2.micro"
    key_name = "main-key"
    depends_on = [aws_eip.one]

    network_interface {
        network_interface_id = aws_network_interface.web-server-nic.id
        device_index = 0
    }

    user_data = "${file("install.sh")}"
    tags = {
        Name = "EC2 Instance"
    }
}