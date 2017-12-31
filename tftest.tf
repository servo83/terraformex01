#Specify the platform to be used and the region and profile to use(points to variables that are referenced in variables.tf)
provider "aws" {
    region = "${var.region}"
    profile = "${var.profile}"
}

#Create and specify VPC ID as well as the CIDR range to use
resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
}

# Creates an internet gateway to give our subnet access to the open internet

resource "aws_internet_gateway" "internet-gateway" {
    vpc_id = "${aws_vpc.vpc.id}"
}

# Gives the VPC internet access by referencing it in the main route table.

resource "aws_route" "internet_access" {
    route_table_id		= "${aws_vpc.vpc.main_route_table_id}"
    destination_cidr_block	= "0.0.0.0/0"
    gateway_id			= "${aws_internet_gateway.internet-gateway.id}"
}

# Create a subnet to launch our instances into.

resource "aws_subnet" "default" {
    vpc_id			= "${aws_vpc.vpc.id}"
    cidr_block			= "10.0.1.0/24"
    map_public_ip_on_launch	= true

    tags {
        Name = "Public"
    }
}

#Creates default security group to access instances over SSH and HTTP

resource "aws_security_group" "default" {
    name			= "terraform_securitygroup"
    description			= "Used for public instances"
    vpc_id			= "${aws_vpc.vpc.id}"

    # SSH access from anywhere
    ingress {
        from_port	= 22
        to_port		= 22
        protocol 	= "tcp"
        cidr_blocks	= ["0.0.0.0/0"]
    }

    # HTTP access from the VPC
    ingress {
        from_port	= 80
        to_port		= 80
        protocol 	= "tcp"
        cidr_blocks	= ["10.0.0.0/16"]
    }

    # outbound internet access
    egress {
        from_port	= 0
        to_port		= 0
        protocol	= "-1" #This means all protocols.
        cidr_blocks	=["0.0.0.0/0"]
    }
}

#Prompts user for key name and the path to the public key.
resource "aws_key_pair" "auth" {
    key_name	= "${var.key_name}"
    public_key	= "${file(var.public_key_path)}"
}

#Creates the public EC2 instance to be used as the web server.
resource "aws_instance" "web" {
    instance_type = "t2.micro"
    ami = "ami-fce3c696"

    key_name = "${aws_key_pair.auth.id}"
    vpc_security_group_ids = ["${aws_security_group.default.id}"]

    subnet_id = "${aws_subnet.default.id}" #Would typically have web servers in private subnets and have ELB pointing to them.

    #This block tells us how to communicate with the instance. This is AMI specific to the ubuntu image.
    connection {
        user = "ubuntu"
    }

    #This will run a remote script on the instance after creating it to update it, install Nginx and start the service.
    #This should be run on port 8 by default.
    provisioner "remote-exec" {
        inline = [
            "sudo apt-get -y update",
            "sudo apt-get -y install nginx",
            "sudo service nginx start"
        ]
    }
}
