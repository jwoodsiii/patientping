# Add outputs here as resources are defined in main.tf
output "vpc" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
