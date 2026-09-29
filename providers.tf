provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394:Only the first availability_zone_count zones are used, or the explicit availability_zones list; a new AZ does not change the selection.
  state = "available"
}
