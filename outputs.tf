output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "ipv6_cidr_block" {
  value       = aws_vpc.this.ipv6_cidr_block
  description = "IPv6 CIDR Block assigned to VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "subnet ID for created public subnet"
}

output "security_group_id" {
  value       = aws_security_group.public_sg.id
  description = "security group ID"
}

output "instance_id" {
  value       = aws_instance.app.id
  description = "created EC2 instance ID"
}

output "instance_public_ip" {
  value       = aws_instance.app.public_ip
  description = "IPv4 public IP address for created EC2"
}

# output "private_key_pem" {
#  value       = tls_private_key.deployer.private_key_pem
#  description = "created pem private key"
#  sensitive   = true
# }
