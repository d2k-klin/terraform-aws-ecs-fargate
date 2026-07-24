locals {
  name = "${var.name}-${var.environment}"

  availability_zones = var.availability_zones != null ? var.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    min(var.availability_zone_count, length(data.aws_availability_zones.available.names))
  )

  private_subnets  = var.private_subnets != null ? var.private_subnets : [for index, _ in local.availability_zones : cidrsubnet(var.vpc_cidr, 8, index)]
  public_subnets   = var.public_subnets != null ? var.public_subnets : [for index, _ in local.availability_zones : cidrsubnet(var.vpc_cidr, 8, 32 + index)]
  database_subnets = var.database_subnets != null ? var.database_subnets : [for index, _ in local.availability_zones : cidrsubnet(var.vpc_cidr, 8, 64 + index)]

  capacity_provider_strategy = var.use_fargate_spot ? {
    FARGATE_SPOT = {
      weight = 1
      base   = 1
    }
    } : {
    FARGATE = {
      weight = 1
      base   = 1
    }
  }

  tags = merge({
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
  }, var.tags)
}
