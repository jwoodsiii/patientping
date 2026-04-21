terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # These values are outputs from the bootstrap stack.
  # The key is the only thing that changes per stack - it namespaces state
  # within the shared bucket.
  backend "s3" {
    bucket         = "jwoodsiii-tfstate-bootdev"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jwoodsiii-tfstate-locks"
    encrypt        = true
  }
}
