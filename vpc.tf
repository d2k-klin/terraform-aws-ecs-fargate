provider "aws" {
  region = var.aws-region
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=v2.77.0"

  name = "dev-vpc"

  cidr = var.cidr

  azs              = var.availability_zones
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.db_subnets

  create_database_subnet_group = true

  manage_default_route_table = true
  default_route_table_tags   = { DefaultRouteTable = true }

  enable_ipv6 = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  # enable_s3_endpoint       = true
  # enable_dynamodb_endpoint = true

  # # VPC endpoint for SSM
  # enable_ssm_endpoint              = true
  # ssm_endpoint_private_dns_enabled = true
  # ssm_endpoint_security_group_ids  = [data.aws_security_group.default.id]


  # VPC Endpoint for ECR API
  # enable_ecr_api_endpoint              = true
  # ecr_api_endpoint_policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
  # ecr_api_endpoint_private_dns_enabled = true
  # ecr_api_endpoint_security_group_ids  = [module.enpoints_sg.this_security_group_id]

  # # # VPC Endpoint for ECR DKR
  # enable_ecr_dkr_endpoint              = true
  # ecr_dkr_endpoint_policy              = data.aws_iam_policy_document.generic_endpoint_policy.json
  # ecr_dkr_endpoint_private_dns_enabled = true
  # ecr_dkr_endpoint_security_group_ids  = [module.enpoints_sg.this_security_group_id]

  # # VPC endpoint for ECS
  # enable_ecs_endpoint              = true
  # ecs_endpoint_private_dns_enabled = true
  # ecs_endpoint_security_group_ids  = [data.aws_security_group.default.id]

  # # VPC endpoint for ECS telemetry
  # enable_ecs_telemetry_endpoint              = true
  # ecs_telemetry_endpoint_private_dns_enabled = true
  # ecs_telemetry_endpoint_security_group_ids  = [data.aws_security_group.default.id]

  # # VPC endpoint for CodeDeploy
  # enable_codedeploy_endpoint              = true
  # codedeploy_endpoint_private_dns_enabled = true
  # codedeploy_endpoint_security_group_ids  = [data.aws_security_group.default.id]

  # # VPC endpoint for CodeDeploy Commands Secure
  # enable_codedeploy_commands_secure_endpoint              = true
  # codedeploy_commands_secure_endpoint_private_dns_enabled = true
  # codedeploy_commands_secure_endpoint_security_group_ids  = [data.aws_security_group.default.id]

  # Default security group - ingress/egress rules cleared to deny all
  #  manage_default_security_group  = true
  #  default_security_group_ingress = []
  #  default_security_group_egress  = []

  public_subnet_tags = {
    Name = "overridden-name-public"
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    Name = "dev-vpc"
  }
}

