module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${local.name}-vpc"

  cidr = var.vpc_cidr

  azs              = local.availability_zones
  private_subnets  = local.private_subnets
  public_subnets   = local.public_subnets
  database_subnets = local.database_subnets

  create_database_subnet_group = true

  manage_default_route_table = true
  default_route_table_tags   = { DefaultRouteTable = true }

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  tags = local.tags
}
