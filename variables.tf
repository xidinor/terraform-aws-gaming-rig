variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_cidr" {
  description = "IPv4 CIDR of VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "IPv4 CIDR for public subnets in VPC (order by AZ in azs)"
  type        = list(string)
  default     = ["172.16.1.0/24", "172.16.2.0/24"]
}

variable "instance_ami" {
  description = "AMI ID for EC2 (e.g. Windows Server)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "g5.2xlarge"
}

variable "key_name" {
  description = "EC2 keypair name. If not exists or null specified, generate new one."
  type        = string
  default     = null
}