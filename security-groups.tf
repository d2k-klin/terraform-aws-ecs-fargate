# CloudFront publishes this prefix list for traffic to customer origins.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.create_cdn ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

# The ALB accepts either CloudFront VPC-origin traffic or explicitly allowed
# public CIDRs, depending on whether the CDN is enabled.
module "http_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${local.name}-http-sg"
  description = var.create_cdn ? "CloudFront traffic to the private application load balancer" : "Public web traffic to the application load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = merge(
    var.create_cdn ? {
      cloudfront_http = {
        from_port      = 80
        to_port        = 80
        ip_protocol    = "tcp"
        prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront[0].id
        description    = "HTTP ingress from CloudFront VPC origins"
      }
    } : {},
    !var.create_cdn ? {
      for index, cidr in var.allowed_ipv4_cidr_blocks : "http_${index}" => {
        from_port   = 80
        to_port     = 80
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
        description = "HTTP ingress"
      }
    } : {},
    !var.create_cdn && var.certificate_arn != null ? {
      for index, cidr in var.allowed_ipv4_cidr_blocks : "https_${index}" => {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
        description = "HTTPS ingress"
      }
    } : {}
  )

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }
  }

  tags = local.tags
}

# ECS tasks: only the ALB may reach the container port.
module "ecs_task_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${local.name}-ecs-task-sg"
  description = "Container port open to the ALB security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_alb = {
      from_port                    = var.container_port
      to_port                      = var.container_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.http_sg.id
      description                  = "ECS access from ALB"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }
  }

  tags = local.tags
}

# RDS: only ECS tasks may reach Postgres. Created only when RDS is enabled.
module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  create      = var.create_postgresql
  name        = "${local.name}-rds-sg"
  description = "Postgres open to the ECS task security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_ecs = {
      from_port                    = 5432
      to_port                      = 5432
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.ecs_task_sg.id
      description                  = "ECS access to RDS"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }
  }

  tags = local.tags
}

# EFS: only ECS tasks may reach NFS. Created only when EFS is enabled.
module "efs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  create      = var.create_efs
  name        = "${local.name}-efs-sg"
  description = "NFS open to the ECS task security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_ecs = {
      from_port                    = 2049
      to_port                      = 2049
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.ecs_task_sg.id
      description                  = "ECS access to EFS"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "All outbound"
    }
  }

  tags = local.tags
}
