output "vpc_id" {
  description = "VPC ID — referenced by any stack deploying resources into this VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by name — for load balancers, bastion hosts, public-facing resources"
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs keyed by name — for app servers, RDS, internal services"
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "igw_id" {
  description = "Internet gateway ID"
  value       = aws_internet_gateway.main.id
}
