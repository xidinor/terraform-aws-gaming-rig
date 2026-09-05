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

variable "instance_az" {
  description = "Placement AZ selected by apply_with_az_fallback.py. Null uses the first AZ in azs."
  type        = string
  default     = null
}

variable "aws_max_retries" {
  description = "AWS API retry limit. Null keeps the provider default; the apply helper uses 2 to surface capacity errors sooner."
  type        = number
  default     = null

  validation {
    condition     = var.aws_max_retries == null ? true : var.aws_max_retries >= 0 && floor(var.aws_max_retries) == var.aws_max_retries
    error_message = "aws_max_retries must be null or a non-negative integer."
  }
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
  description = "AMI ID for EC2. If null, resolve Windows Server 2025 English Full Base from SSM Parameter Store."
  type        = string
  default     = null
}

# SSM parameter for fallback: Windows Server 2025 English Full Base latest
variable "ssm_ami_parameter_name" {
  description = "Fallback SSM parameter for OS/language"
  type        = string
  default     = "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "g5.2xlarge"
}

variable "key_name" {
  description = "Existing EC2 key-pair name. If null, generate a new key pair and save its private key locally."
  type        = string
  default     = null
}
