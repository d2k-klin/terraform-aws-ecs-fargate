module "alb_ecs" {
  source = "github.com/terraform-aws-modules/terraform-aws-alb.git?ref=v5.12.0"

  name = "${var.name}-${var.environment}"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.http_sg.this_security_group_id]

  target_groups = [
    {
      name_prefix      = "pri-"
      backend_protocol = "HTTP"
      backend_port     = 5000
      target_type      = "ip"
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
    },
    {
      name_prefix      = "sec-"
      backend_protocol = "HTTP"
      backend_port     = 5000
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/ping"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      }

    },
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
    {
      port               = 8080
      protocol           = "HTTP"
      target_group_index = 1
    },
  ]

  tags = local.tags
}