# Configure the AWS Provider
provider "aws" {
  region  = "ap-southeast-2"
  access_key = "****"
  secret_key = "*****"

#create custom vpc
resource "aws_vpc" "terraformVPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
      name = "terraformVPC"
  }
}


#creating a internet gateway

resource "aws_internet_gateway" "TF-GW" {
  vpc_id = aws_vpc.terraformVPC.id

  tags = {
    Name = "TF-IG"
  }
}

#creating a custom route table

resource "aws_route_table" "TF-RT" {
  vpc_id = aws_vpc.terraformVPC.id

  route {
    cidr_block = "10.0.0.0/0"
    gateway_id = aws_internet_gateway.TF-GW.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.TF-GW.id
  }

  tags = {
    Name = "TF"
  }
}


#create a subnet
resource "aws_subnet" "TF-subnet-1"{
    vpc_id = aws_vpc.terraformVPC.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-southeast-2a"
    tags = {
        name = "Terraform-Subnet"
    }
}

#assigning the subnet just created to the route table we just created using route table association 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.TF-subnet-1.id
  route_table_id = aws_route_table.TF-RT.id
}

#create security group to allow port 22, 80 443

resource "aws_security_group" "TF-allow_web" {
  name        = "TF-Allow-WEbAccess"
  description = "allow web traffic"
  vpc_id      = aws_vpc.terraformVPC.id

  ingress {
    description      = "HTTPS"
    from_port        = 443    
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80    
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 22    
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
#were allowing all ports for the egress and the -1 in protocol means all traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TF-WebAccess"
  }
}


#creating a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "Web-server-ray" {
  subnet_id       = aws_subnet.TF-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.TF-allow_web.id]
}

#Assinging a elsatic ip address to the network interface created in step 7
resource "aws_eip" "TF-E-IP" {
  vpc                       = true
  network_interface         = aws_network_interface.Web-server-ray.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.TF-GW]
}


#creating an lunux server and installing/ enabling apache2
resource "aws_instance" "web_server_instance"{
  ami = "ami-0bd2230cfb28832f7"
  instance_type = "t2.micro"
  availability_zone = "ap-southeast-2a"
  key_pair = "Sydney-kp"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.Web-server-ray.id
  }
  
  user_data = <<EOF
#!/bin/bash
yum update -y
yum install httpd -y
systemctl start httpd
systemctl enable httpd
cd /var/www/html
aws s3 cp s3://rihan97/names.csv ./
aws s3 cp s3://rihan97/index.txt ./
EC2NAME=`cat ./names.csv|sort -R|head -n 1|xargs` 
sed "s/INSTANCE/$EC2NAME/" index.txt > index.html
EOF
                
}
