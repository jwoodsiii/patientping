module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.project
  cidr = "10.0.0.0/22"
  azs  = ["us-east-1a", "us-east-1b"]

  private_subnets = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets  = ["10.0.2.0/24", "10.0.3.0/24"]

  private_subnet_names = ["patientping-private-a", "patientping-private-b"]
  public_subnet_names  = ["patientping-public-a", "patientping-public-b"]

  # Disable the module's IGW and public route table so we own them below.
  # The module will still create the public subnets themselves.
  create_igw = false

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name        = "patientping-igw"
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_route_table" "public" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "patientping-public-rt"
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_route_table_association" "public" {
  count = length(module.vpc.public_subnets)

  subnet_id      = module.vpc.public_subnets[count.index]
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name        = "patientping-private-rt"
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_route_table_association" "private" {
  count = length(module.vpc.private_subnets)

  subnet_id      = module.vpc.private_subnets[count.index]
  route_table_id = aws_route_table.private.id
}
