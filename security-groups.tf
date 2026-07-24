# Public-facing ALB security group: HTTP in from anywhere, all out.
module "http_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "${local.name}-http-sg"
  description = "HTTP/8080 open to the world (IPv4); egress open"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from anywhere"
    }
    http_secondary = {
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Secondary listener (blue/green) from anywhere"
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

# ECS tasks: only the ALB may reach the container port.
module "ecs_task_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

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
  version = "~> 6.0"

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

# EFS: only ECS tasks may reach NFS.
module "efs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

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
