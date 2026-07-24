module "fargate_ecs" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 7.0"

  name = "${local.name}-fargate"

  setting = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  # Managed Fargate capacity providers (no EC2 ASGs).
  cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = {
    FARGATE_SPOT = {
      weight = 1
      base   = 1
    }
    FARGATE = {
      weight = 0
    }
  }

  tags       = local.tags
  depends_on = [module.vpc]
}
