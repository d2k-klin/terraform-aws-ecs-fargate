# Remote state backend.
#
# Fill in your own S3 bucket (and optionally uncomment to enable). Until then
# Terraform uses local state, so you can `terraform init` and try things out
# immediately. See the README ("Remote state backend") to create the bucket.
#
# S3 native state locking (use_lockfile) replaces the old DynamoDB lock table
# and needs Terraform >= 1.11.
#
# terraform {
#   backend "s3" {
#     bucket       = "CHANGE-ME-your-terraform-state-bucket"
#     key          = "terraform-aws-ecs-fargate/terraform.tfstate"
#     region       = "eu-central-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
