// variables.tf
variable "region" {
  description = "AWS EC2 instance region (Japan East)"
  type        = string
  default     = "ap-northeast-1"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_cidr" {
  description = "VPC Network CIDR Block"
  type        = string
  default     = "172.16.0.0/20"
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR (order by AZ)"
  type        = list(string)
  default     = ["172.16.0.0/24", "172.16.1.0/24"]
}

variable "instance_ami" {
  description = "Windows Server 2025 AMI (standard Windows Server AMI)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "g6.2xlarge"
}
