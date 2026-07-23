# ============================================================
# Networking Module — Outputs
# ============================================================

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.cost_opt_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private_subnet.id
}

output "lambda_sg_id" {
  description = "ID of the security group assigned to Lambda"
  value       = aws_security_group.lambda_sg.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}
