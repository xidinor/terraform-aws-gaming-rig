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

# 1) VPC（IPv6自動割当、DNS有効）
resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = { Name = "simple-gaming-vpc" }
}

# 2) インターネットゲートウェイ
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "simple-gaming-igw" }
}

# 3) パブリックサブネット（2AZ、IPv6自動付与）
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

# 4) ルートテーブル（IPv4/IPv6デフォルト）
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

# 5) セキュリティグループ (3389/8443/38810/38820/38830/38840 を IPv4/IPv6 全開放)
resource "aws_security_group" "public_sg" {
  name        = "simple-gaming-sg"
  description = "Allow inbound MS-RDP, Amazon DCV, Virtual Desktop from anywhere"
  vpc_id      = aws_vpc.this.id

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

  # 送信はIPv4/IPv6とも全面許可
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "simple-gaming-sg" }
}

# 6) RSA キーペア生成
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "simple-gaming-login-key"
  public_key = tls_private_key.deployer.public_key_openssh
}

# 7) EC2（g6.2xlarge、64GiB、永続スポット：中断=停止）
resource "aws_instance" "app" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id     # 最初のサブネットに配置
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
      spot_instance_type = "persistent" # 永続
      instance_interruption_behavior = "stop" # 中断=停止
      # max_price 未指定（上限なし）、valid_until 未指定（無期限）
    }
  }

  tags = { Name = "simple-gaming-pc" }
}
