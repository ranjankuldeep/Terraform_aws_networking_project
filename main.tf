provider "aws" {
  region     = "us-east-1"
  secret_key = "cyxliuK5CKlxPoqCXU6a/G+MjST1tNJJlaTydk2x"
  access_key = "AKIASDGMDTQPLLC4KRGV"
}
//VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-first-vpc"
  }
}
//Internet Gateway
resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "my-internet-gateway"
  }
}
//Elatic IP for NAT Gateway
resource "aws_eip" "nat-eip" {
  instance = null
  domain   = "vpc"
  tags = {
    Name = "my-nat-eip"
  }
  depends_on = [aws_internet_gateway.prod-igw]
}
//Subnet Private
resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "my-private-subnet"
  }
}
//Subnet Public
resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "my-public-subnet"
  }
}

//Nat Gateway and allocation to eip-nat
resource "aws_nat_gateway" "prod-ngw" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.private-subnet.id
  tags = {
    Name = "my-nat-gateway"
  }
  depends_on = [aws_internet_gateway.prod-igw]
}

//Route Table PUBLIC
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}
// Public Subnet Association
resource "aws_route_table_association" "public-subnet-association" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-route-table.id
}
//Route Table PRIVATE
resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.prod-ngw.id
  }
  tags = {
    Name = "private-route-table"
  }
}
// Private Subnet Association
resource "aws_route_table_association" "private-subnet-association" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-route-table.id
}

//Network Interface for EC2 instance in public subnet 
resource "aws_network_interface" "ec2-nic-public" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.sg-public.id]
}
//Network Interface for EC2 instance in private subnet 
resource "aws_network_interface" "ec2-nic-private" {
  subnet_id       = aws_subnet.private-subnet.id
  private_ips     = ["10.0.1.40"]
  security_groups = [aws_security_group.sg-private.id]
}
//Security Group for Private EC2 instances
resource "aws_security_group" "sg-private" {
  name        = "my-sg-private"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "my-sg-private"
  }
}
//Security Group for Public EC2 instances
resource "aws_security_group" "sg-public" {
  name        = "my-sg-public"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "my-sg-public"
  }
}
//EC2 Instance in PRIVATE subnet
resource "aws_instance" "ec2-private" {
  ami               = "ami-0fc5d935ebf8bc3bc"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "demoKeyPair"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.ec2-nic-private.id
  }
}
// EC2 Instance in PUBLIC subnet
resource "aws_instance" "ec2-public" {
  ami               = "ami-0fc5d935ebf8bc3bc"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "demoKeyPair"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.ec2-nic-public.id
  }
}
resource "aws_eip" "public-eip" {
  instance = aws_instance.ec2-public.id
  domain   = "vpc"
  tags = {
    Name = "my-ec2-public-eip"
  }
  depends_on = [aws_internet_gateway.prod-igw]
}
