
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, {
    ManagedBy = "terraform"
  })
}


data "aws_iam_policy_document" "scan_trust" {
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

data "aws_iam_policy_document" "scan_state" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [var.state_bucket_arn, "${var.state_bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [var.table_arn]
  }
}

resource "aws_iam_role_policy" "scan_state" {
  name   = "tf-scan-state-access"
  role   = aws_iam_role.scan.id
  policy = data.aws_iam_policy_document.scan_state.json
}

resource "aws_iam_role_policy_attachment" "scan_readonly" {
  count = var.scan_policy_mode == "managed" ? 1 : 0

  role       = aws_iam_role.scan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "scan_inline" {
  for_each = var.scan_policy_mode == "inline" ? toset(var.scan_inline_policy_arns) : toset([])

  role       = aws_iam_role.scan.name
  policy_arn = each.value
}


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

resource "aws_iam_role_policy_attachment" "apply_admin" {
  count = var.apply_policy_mode == "admin" ? 1 : 0

  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "apply_inline" {
  for_each = var.apply_policy_mode == "inline" ? toset(var.apply_inline_policy_arns) : toset([])

  role       = aws_iam_role.apply.name
  policy_arn = each.value
}
