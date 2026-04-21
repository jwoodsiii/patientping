# One OIDC provider per AWS account - reusable across any number of roles.
# The thumbprint_list value is a legacy field; AWS STS validates GitHub's OIDC
# tokens against its own root CA store since mid-2023. Terraform still requires
# the field, so we pass GitHub's well-known thumbprint.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, {
    ManagedBy = "terraform"
  })
}

# ─── Scan role ────────────────────────────────────────────────────────────────
# Trusted from any PR in the specific repo. Read-only downstream - a malicious
# PR modifying the workflow can't escalate because the role has no write perms.

data "aws_iam_policy_document" "scan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # prevents token replay from workflows targeting other audiences
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Full repo path - StringEquals not StringLike, so wildcards don't apply.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "scan" {
  name                 = "tf-scan-role"
  assume_role_policy   = data.aws_iam_policy_document.scan_trust.json
  description          = "Read-only role for terraform plan + security scans from PRs"
  max_session_duration = 3600

  tags = merge(var.tags, { ManagedBy = "terraform" })
}

data "aws_iam_policy_document" "scan_permissions" {
  # State read - needed for terraform plan to compare desired vs actual state
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.state_bucket_arn, "${var.state_bucket_arn}/*"]
  }

  # Lock table - plan acquires and releases a lock even for read operations
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [var.table_arn]
  }

  # Read-only AWS API calls for plan to resolve current resource state.
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "iam:Get*",
      "iam:List*",
      "s3:GetBucket*",
      "s3:ListAllMyBuckets",
      "rds:Describe*",
      "lambda:Get*",
      "lambda:List*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "scan" {
  name   = "tf-scan-permissions"
  role   = aws_iam_role.scan.id
  policy = data.aws_iam_policy_document.scan_permissions.json
}

# ─── Apply role ───────────────────────────────────────────────────────────────
# Trusted only from jobs that declare `environment: <apply_environment>` in GHA
# AND have passed that environment's protection rules (required reviewers etc).
# The environment claim only appears in the OIDC token after approval - this is
# a separate enforcement layer on top of branch protection.

data "aws_iam_policy_document" "apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:environment:${var.apply_environment}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = "tf-apply-role"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  description          = "Apply role for terraform - gated by GHA environment approval"
  max_session_duration = 3600

  tags = merge(var.tags, { ManagedBy = "terraform" })
}

# AdministratorAccess is intentionally broad for a learning project where the
# set of AWS services is unknown upfront. In production, replace this with
# per-service policies scoped to resources tagged managed-by=terraform.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# State write - separate from the admin attachment so the boundary is legible
# when you eventually scope down the admin grant.
data "aws_iam_policy_document" "apply_state" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [var.state_bucket_arn, "${var.state_bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [var.table_arn]
  }
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "tf-apply-state-access"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_state.json
}
