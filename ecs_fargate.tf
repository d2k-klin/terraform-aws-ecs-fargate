module "fargate_ecs" {
  source = "github.com/terraform-aws-modules/terraform-aws-ecs.git?ref=v2.8.0"

  name = "${local.name}-fargate"

  container_insights = true

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 1
    }
  ]

  tags       = local.tags
  depends_on = [module.vpc]
}
