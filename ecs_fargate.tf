module "fargate_ecs" {
  # checkov:skip=CKV_TF_1:Registry module pinned to an exact version; Dependabot proposes reviewed updates.
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.6.1"

  name = "${local.name}-fargate"

  setting = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  cloudwatch_log_group_retention_in_days = var.log_retention_days

  cluster_capacity_providers         = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = local.capacity_provider_strategy

  tags = local.tags
}
