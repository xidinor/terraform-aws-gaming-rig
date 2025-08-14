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

# SSM parameter for fallback: Windows Server 2025 English Full Base latest
variable "ssm_ami_parameter_name" {
  description = "Fallback SSM parameter for OS/Launguage"
  type        = string
  default     = "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "g5.2xlarge"
}

variable "key_name" {
  description = "EC2 key-pair name. If not exists or null specified, generate new one."
  type        = string
# default     = null
}

# Mode for Spot max price. "none" = no max (default), "buffer_above_spot" = latest Spot * (1 + buffer).
variable "spot_max_price_mode" {
  description = "none | buffer_above_spot"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "buffer_above_spot"], var.spot_max_price_mode)
    error_message = "spot_max_price_mode must be one of: none, buffer_above_spot."
  }
}

# Buffer ratio over the latest Spot price (e.g., 0.10 means +10%).
variable "spot_price_buffer_ratio" {
  description = "Buffer ratio over latest Spot price (e.g., 0.10 = +10%)"
  type        = number
  default     = 0.10
}

# Product description used to fetch Spot price. Typical values: "Windows" or "Linux/UNIX".
variable "spot_product_description" {
  description = "Spot price product description (e.g., Windows or Linux/UNIX)"
  type        = string
  default     = "Windows"
}
