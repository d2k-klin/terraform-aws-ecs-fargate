module "alb_ecs" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.0"

  name = local.name

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Reuse the shared HTTP security group instead of creating one.
  create_security_group = false
  security_groups       = [module.http_sg.id]

  listeners = merge(
    var.certificate_arn == null ? {
      http = {
        port     = 80
        protocol = "HTTP"
        forward = {
          target_group_key = "primary"
        }
      }
    } : {},
    var.certificate_arn != null ? {
      http_redirect = {
        port     = 80
        protocol = "HTTP"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }
    } : {},
    var.certificate_arn != null ? {
      https = {
        port            = 443
        protocol        = "HTTPS"
        ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
        certificate_arn = var.certificate_arn
        forward = {
          target_group_key = "primary"
        }
      }
    } : {}
  )

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
  }

  tags = local.tags
}
