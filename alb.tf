module "alb_ecs" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name = local.name

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Reuse the shared HTTP security group instead of creating one.
  create_security_group = false
  security_groups       = [module.http_sg.id]

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "primary"
      }
    }
    # Secondary listener used by CodeDeploy for blue/green deployments.
    http_secondary = {
      port     = 8080
      protocol = "HTTP"
      forward = {
        target_group_key = "secondary"
      }
    }
  }

  target_groups = {
    primary = {
      name_prefix = "pri-"
      protocol    = "HTTP"
      port        = var.container_port
      target_type = "ip"
      # ECS registers/deregisters targets itself; don't attach here.
      create_attachment = false
      health_check = {
        enabled             = true
        interval            = 30
        path                = var.health_check_path
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
    secondary = {
      name_prefix       = "sec-"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false
      health_check = {
        enabled             = true
        interval            = 30
        path                = var.health_check_path
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  }

  tags = local.tags
}
