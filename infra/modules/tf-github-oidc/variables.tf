variable "github_org" {
  description = "GitHub org or username — used to scope OIDC trust to a specific owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name — full repo path is OWNER/REPO, scoped here to prevent other repos under the same org from assuming these roles"
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the S3 state bucket — grants both roles read access, apply role gets write access"
  type        = string
}

variable "table_arn" {
  description = "ARN of the DynamoDB lock table — grants both roles read/write for lock acquisition"
  type        = string
}

variable "apply_environment" {
  description = "Name of the GitHub Actions environment that gates apply runs. The apply role trust policy requires this environment claim in the OIDC token, meaning GHA environment protection rules (required reviewers, wait timers) must pass before the token is minted."
  type        = string
  default     = "production"
}

variable "scan_policy_mode" {
  description = <<-EOT
    Controls how read permissions are granted to the scan role.
    - "managed"  : attaches AWS ReadOnlyAccess managed policy. Covers all services
                   automatically as your stack grows. Broader than strictly necessary
                   but zero maintenance overhead. Recommended for personal projects.
    - "inline"   : uses a manually maintained inline policy scoped to specific
                   Describe/List/Get actions. Must be extended as new services are
                   added to the stack. Recommended for production where least
                   privilege per-service is required.
  EOT
  type        = string
  default     = "managed"

  validation {
    condition     = contains(["managed", "inline"], var.scan_policy_mode)
    error_message = "scan_policy_mode must be either 'managed' or 'inline'."
  }
}

variable "apply_policy_mode" {
  description = <<-EOT
    Controls how write permissions are granted to the apply role.
    - "admin"    : attaches AdministratorAccess. Covers all services automatically.
                   Appropriate for personal projects where the service scope is
                   unknown or frequently changing.
    - "inline"   : uses a manually maintained inline policy scoped to specific
                   services. Must be extended as new services are added. Recommended
                   for production where blast radius of the apply role must be
                   minimized.
  EOT
  type        = string
  default     = "admin"

  validation {
    condition     = contains(["admin", "inline"], var.apply_policy_mode)
    error_message = "apply_policy_mode must be either 'admin' or 'inline'."
  }
}

variable "scan_inline_policy_arns" {
  description = "Additional managed policy ARNs to attach to the scan role when scan_policy_mode = 'inline'. Use to grant access to specific services beyond the baseline state/lock permissions."
  type        = list(string)
  default     = []
}

variable "apply_inline_policy_arns" {
  description = "Additional managed policy ARNs to attach to the apply role when apply_policy_mode = 'inline'. Use to grant write access to specific services the stack manages."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
