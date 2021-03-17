module "ecs_service_noa" {
  source = "./modules/ecs-noa"

  ecs_cluster_arn           = module.fargate_ecs.this_ecs_cluster_id
  security_group_ids        = [module.ecs_task_sg.this_security_group_id]
  subnet_ids                = module.vpc.private_subnets
  alb_target_group_arn      = module.alb_ecs.target_group_arns[0]
  docker_image              = "${local.account}.dkr.ecr.${var.aws-region}.amazonaws.com/${var.container_image}:latest"
  ecs_cluster_name          = module.fargate_ecs.this_ecs_cluster_name
  lb_arn_suffix             = module.alb_ecs.this_lb_arn_suffix
  target_group_arn_suffixes = module.alb_ecs.target_group_arn_suffixes[0]

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
