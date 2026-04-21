output "bucket_name" {
  description = "S3 bucket name - use this in backend blocks of other stacks"
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "S3 bucket ARN - use this in IAM policy resources"
  value       = aws_s3_bucket.state.arn
}

output "table_name" {
  description = "DynamoDB table name - use this in backend blocks of other stacks"
  value       = aws_dynamodb_table.locks.id
}

output "table_arn" {
  description = "DynamoDB table ARN - use this in IAM policy resources"
  value       = aws_dynamodb_table.locks.arn
}
