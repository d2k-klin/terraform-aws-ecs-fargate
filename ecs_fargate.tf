module "fargate_ecs" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = "${local.name}-fargate"

  setting = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  cluster_capacity_providers         = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = local.capacity_provider_strategy

  tags = local.tags
}
