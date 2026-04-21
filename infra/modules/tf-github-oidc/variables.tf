variable "github_org" {
  description = "GitHub org or username - used to scope OIDC trust to a specific owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name - full repo path is OWNER/REPO, scoped here to prevent other repos under the same org from assuming these roles"
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the S3 state bucket - grants both roles read access, apply role gets write access"
  type        = string
}

variable "table_arn" {
  description = "ARN of the DynamoDB lock table - grants both roles read/write for lock acquisition"
  type        = string
}

variable "apply_environment" {
  description = "Name of the GitHub Actions environment that gates apply runs. The apply role trust policy requires this environment claim in the OIDC token, meaning GHA environment protection rules (required reviewers, wait timers) must pass before the token is minted."
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
