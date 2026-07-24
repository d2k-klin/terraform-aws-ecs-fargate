module "ecs_service_noa" {
  source = "./modules/ecs-noa"

  ecs_cluster_arn           = module.fargate_ecs.arn
  security_group_ids        = [module.ecs_task_sg.id]
  subnet_ids                = module.vpc.private_subnets
  alb_target_group_arn      = module.alb_ecs.target_groups["primary"].arn
  docker_image              = "${local.account}.dkr.ecr.${var.aws-region}.amazonaws.com/${var.container_image}:latest"
  ecs_cluster_name          = module.fargate_ecs.name
  lb_arn_suffix             = module.alb_ecs.arn_suffix
  target_group_arn_suffixes = module.alb_ecs.target_groups["primary"].arn_suffix

  #Task Vars
  cw_arn         = aws_cloudwatch_log_group.main.name
  aws-region     = var.aws-region
  file_system_id = aws_efs_file_system.this.id
  tags           = local.tags
}

resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/${local.name}-task"

  tags = local.tags
}
