module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  name        = local.name
  cluster_arn = module.fargate_ecs.arn

  cpu           = var.container_cpu
  memory        = var.container_memory
  desired_count = var.service_desired_count

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  capacity_provider_strategy = {
    for provider, strategy in local.capacity_provider_strategy : provider => {
      capacity_provider = provider
      weight            = strategy.weight
      base              = strategy.base
    }
  }

  subnet_ids            = module.vpc.private_subnets
  security_group_ids    = [module.ecs_task_sg.id]
  create_security_group = false

  load_balancer = {
    service = {
      target_group_arn = module.alb_ecs.target_groups["primary"].arn
      container_name   = local.name
      container_port   = var.container_port
    }
  }

  container_definitions = {
    app = {
      name      = local.name
      image     = var.container_image
      essential = true

      portMappings = [{
        name          = local.name
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      environment = [
        for name, value in var.container_environment : {
          name  = name
          value = value
        }
      ]
      secrets = [
        for name, value_from in var.container_secrets : {
          name      = name
          valueFrom = value_from
        }
      ]
      mountPoints = var.create_efs ? [{
        sourceVolume  = "efs"
        containerPath = var.container_mount_path
      }] : []

      readonlyRootFilesystem                 = false
      cloudwatch_log_group_name              = "/ecs/${local.name}"
      cloudwatch_log_group_retention_in_days = var.log_retention_days
      cloudwatch_log_group_use_name_prefix   = false
    }
  }

  volume = var.create_efs ? {
    efs = {
      name = "efs"
      efs_volume_configuration = {
        file_system_id     = aws_efs_file_system.this[0].id
        transit_encryption = "ENABLED"
      }
    }
  } : {}

  autoscaling_min_capacity = var.autoscaling_min_capacity
  autoscaling_max_capacity = var.autoscaling_max_capacity
  autoscaling_policies = {
    cpu = {
      name        = "cpu-autoscaling"
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value       = 70
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
      }
    }
    memory = {
      name        = "memory-autoscaling"
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
        target_value       = 75
        scale_in_cooldown  = 300
        scale_out_cooldown = 300
      }
    }
  }

  task_exec_iam_role_name = "${local.name}-execution"
  tasks_iam_role_name     = "${local.name}-task"
  task_exec_iam_role_policies = {
    for arn in var.task_execution_policy_arns : arn => arn
  }
  tasks_iam_role_policies = {
    for arn in var.task_policy_arns : arn => arn
  }
  task_exec_secret_arns = [
    for arn in values(var.container_secrets) : arn if strcontains(arn, ":secretsmanager:")
  ]
  task_exec_ssm_param_arns = [
    for arn in values(var.container_secrets) : arn if strcontains(arn, ":ssm:")
  ]

  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"
  tags                    = local.tags

  depends_on = [aws_efs_mount_target.this]
}

moved {
  from = module.ecs_service_noa
  to   = module.ecs_service
}

moved {
  from = module.ecs_service.aws_ecs_service.main
  to   = module.ecs_service.aws_ecs_service.this[0]
}

moved {
  from = module.ecs_service.aws_ecs_task_definition.main
  to   = module.ecs_service.aws_ecs_task_definition.this[0]
}

moved {
  from = module.ecs_service.aws_appautoscaling_target.ecs_target
  to   = module.ecs_service.aws_appautoscaling_target.this[0]
}

moved {
  from = module.ecs_service.aws_appautoscaling_policy.ecs_policy_cpu
  to   = module.ecs_service.aws_appautoscaling_policy.this["cpu"]
}

moved {
  from = module.ecs_service.aws_appautoscaling_policy.ecs_policy_memory
  to   = module.ecs_service.aws_appautoscaling_policy.this["memory"]
}

moved {
  from = module.ecs_service.aws_iam_role.ecs_task_execution_role
  to   = module.ecs_service.aws_iam_role.task_exec[0]
}

moved {
  from = module.ecs_service.aws_iam_role.ecs_task_role
  to   = module.ecs_service.aws_iam_role.tasks[0]
}

moved {
  from = module.ecs_service.aws_iam_role_policy_attachment.ecs-task-execution-role-policy-attachment
  to   = module.ecs_service.aws_iam_role_policy_attachment.task_exec[0]
}

moved {
  from = aws_cloudwatch_log_group.main
  to   = module.ecs_service.module.container_definition["app"].aws_cloudwatch_log_group.this[0]
}
