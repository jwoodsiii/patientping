locals {
  azs = ["us-east-1a", "us-east-1b"]

  private_subnets = {
    "patientping-private-a" = { cidr = "10.0.0.0/24", az = "us-east-1a" }
    "patientping-private-b" = { cidr = "10.0.1.0/24", az = "us-east-1b" }
  }

  public_subnets = {
    "patientping-public-a" = { cidr = "10.0.2.0/24", az = "us-east-1a" }
    "patientping-public-b" = { cidr = "10.0.3.0/24", az = "us-east-1b" }
  }

  common_tags = {
    Terraform   = "true"
    Environment = "prod"
    Project     = var.project
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/22"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "patientping-vpc"
  })
}

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "patientping-default-sg-DO-NOT-USE"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = each.key
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = each.key
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "patientping-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "patientping-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "patientping-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/patientping-flow-logs"
  retention_in_days = 7
  #checkov:skip=CKV_AWS_338:Retention at 7 days to stay within free tier for personal project
  #checkov:skip=CKV_AWS_158:KMS encryption not used, cost not justified for personal project

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name = "patientping-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "patientping-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        # Scope to the specific log group and its streams
        Resource = [
          aws_cloudwatch_log_group.flow_logs.arn,
          "${aws_cloudwatch_log_group.flow_logs.arn}:log-stream:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        #checkov:skip=CKV_AWS_355:DescribeLogGroups requires wildcard resource; AWS does not support resource-level restrictions for this action
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(local.common_tags, {
    Name = "patientping-flow-logs"
  })
}
