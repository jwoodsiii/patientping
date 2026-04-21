output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider - reference in additional role trust policies if you add more roles later"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "scan_role_arn" {
  description = "ARN of the tf-scan role - paste into scan.yml workflow"
  value       = aws_iam_role.scan.arn
}

output "apply_role_arn" {
  description = "ARN of the tf-apply role - paste into apply.yml workflow"
  value       = aws_iam_role.apply.arn
}
