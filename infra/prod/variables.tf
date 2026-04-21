variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name - applied as a tag to all resources"
  type        = string
  default     = "bootdev-aws"
}
