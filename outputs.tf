output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "ipv6_cidr_block" {
  value       = aws_vpc.this.ipv6_cidr_block
  description = "VPC に割り当てられた IPv6 CIDR（/56）"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "パブリックサブネット IDs"
}

output "security_group_id" {
  value       = aws_security_group.public_sg.id
  description = "セキュリティグループ ID"
}

output "instance_id" {
  value       = aws_instance.app.id
  description = "EC2 インスタンス ID"
}

output "instance_public_ip" {
  value       = aws_instance.app.public_ip
  description = "EC2 のパブリック IPv4"
}

output "private_key_pem" {
  value       = tls_private_key.deployer.private_key_pem
  description = "生成されたキーペアの秘密鍵（PEM）"
  sensitive   = true
}
