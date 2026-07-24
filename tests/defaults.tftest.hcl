mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_ec2_managed_prefix_list" {
    defaults = {
      id = "pl-cloudfront"
    }
  }
}

run "portable_defaults" {
  command = plan

  assert {
    condition     = tolist(output.availability_zones) == tolist(["us-east-1a", "us-east-1b"])
    error_message = "The default deployment must select two available AZs."
  }

  assert {
    condition     = tolist(local.private_subnets) == tolist(["10.0.0.0/24", "10.0.1.0/24"])
    error_message = "Private subnets must be derived predictably from vpc_cidr."
  }

  assert {
    condition     = !var.create_cdn && !var.create_efs && !var.create_postgresql
    error_message = "Costly add-ons must remain opt-in."
  }
}

run "optional_components" {
  command = plan

  variables {
    create_cdn        = true
    create_efs        = true
    create_postgresql = true
  }

  assert {
    condition     = var.create_cdn && var.create_efs && var.create_postgresql
    error_message = "All optional component branches must produce a valid plan."
  }

  assert {
    condition     = output.alb_is_internal
    error_message = "Enabling CloudFront must make the ALB internal."
  }
}
