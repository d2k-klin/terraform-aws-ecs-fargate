provider "aws" {
  region = var.aws-region
}

data "aws_caller_identity" "current" {}
