terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# 1) VPC (IPv6, DNS support enabled)
resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = { Name = "simple-gaming-vpc" }
}

# 2) internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "simple-gaming-igw" }
}

# 3) public subnet (2 AZ, IPv6 enabled)
resource "aws_subnet" "public" {
  count                             = length(var.azs)
  vpc_id                            = aws_vpc.this.id
  cidr_block                        = var.public_subnet_cidrs[count.index]
  ipv6_cidr_block                   = cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, count.index) # /56→/64
  availability_zone                 = var.azs[count.index]
  map_public_ip_on_launch           = true
  assign_ipv6_address_on_creation   = true

  tags = { Name = "simple-gaming-snet-${var.azs[count.index]}" }
}

# 4) route table (IPv4, IPv6 default route)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  tags = { Name = "simple-gaming-rtb" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 5) security group
resource "aws_security_group" "public_sg" {
  name        = "simple-gaming-sg"
  description = "Allow inbound MS-RDP, Amazon DCV, Virtual Desktop from anywhere"
  vpc_id      = aws_vpc.this.id

# ingress: Allow 3389/8443/38810/38820/38830/38840, IPv4/IPv6 both
  ingress {
    description      = "RDP"
    from_port        = 3389
    to_port          = 3389
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Amazon DCV"
    from_port        = 8443
    to_port          = 8443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Virtual Desktop 38810"
    from_port        = 38810
    to_port          = 38810
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Virtual Desktop 38820"
    from_port        = 38820
    to_port          = 38820
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Virtual Desktop 38830"
    from_port        = 38830
    to_port          = 38830
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Virtual Desktop 38840"
    from_port        = 38840
    to_port          = 38840
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # egress traffic: Allow all
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "simple-gaming-sg" }
}

# 6) generate RSA key pair
# Omit EC2 key pair generation because the private key is not retrievable.

# 7) EC2 instance (g6.2xlarge, main storage: 64GiB, persistent spot request: interruption_behavior = stop）
resource "aws_instance" "app" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id     # deploy to 1st subnet
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 64
    volume_type = "gp3"
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type = "persistent"
      instance_interruption_behavior = "stop"
	  max_price = 0.3
      # parameter: valid_until not specified
    }
  }

  tags = { Name = "simple-gaming-pc" }
}
