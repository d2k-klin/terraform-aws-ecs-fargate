mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
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

run "secure_defaults" {
  command = plan

  assert {
    condition     = var.enable_flow_log && module.vpc.vpc_flow_log_destination_type == "cloud-watch-logs"
    error_message = "VPC flow logs must be on by default and sent to CloudWatch Logs."
  }

  assert {
    condition     = var.log_retention_days >= 365
    error_message = "Default log retention must cover at least one year of audit history."
  }

  assert {
    condition     = var.deletion_protection
    error_message = "Deletion protection must be on by default."
  }
}

run "backups_cannot_be_disabled" {
  command = plan

  variables {
    db_backup_retention_days = 0
  }

  expect_failures = [var.db_backup_retention_days]
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
