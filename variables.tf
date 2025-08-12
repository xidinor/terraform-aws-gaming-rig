variable "region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "azs" {
  description = "利用する AZ（2つ）"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_cidr" {
  description = "VPC の IPv4 CIDR"
  type        = string
  default     = "172.16.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットの IPv4 CIDR（AZ順）"
  type        = list(string)
  default     = ["172.16.1.0/24", "172.16.2.0/24"]
}

variable "instance_ami" {
  description = "EC2 起動に使用する AMI（例：Windows Server 等）"
  type        = string
}

variable "instance_type" {
  description = "インスタンスタイプ"
  type        = string
  default     = "g6.2xlarge"
}
