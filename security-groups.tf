module "http_sg" {
  source = "github.com/terraform-aws-modules/terraform-aws-security-group//modules/http-80?ref=v3.18.0"

  name        = "http-sg"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

module "ecs_task_sg" {
  source = "github.com/terraform-aws-modules/terraform-aws-security-group.git?ref=v3.18.0"

  name        = "ecs_task_sg"
  description = "Security group with container ports open for ALB sg"
  vpc_id      = module.vpc.vpc_id
  computed_ingress_with_source_security_group_id = [
    {
      from_port                = 5000
      to_port                  = 5000
      protocol                 = "tcp"
      description              = "ECS access from ALB"
      source_security_group_id = module.http_sg.this_security_group_id
    },
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
  egress_rules                                             = ["all-all"]
}

module "enpoints_sg" {
  source = "github.com/terraform-aws-modules/terraform-aws-security-group.git?ref=v3.18.0"

  name                = "enpoints_sg"
  description         = "Security group for endpoints 443 access"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = [var.cidr]
  ingress_rules       = ["https-443-tcp"]
  egress_rules        = ["all-all"]
}

module "rds_sg" {
  source = "github.com/terraform-aws-modules/terraform-aws-security-group.git?ref=v3.18.0"

  create              = var.create_postgresql
  name                = "rds_sg"
  description         = "Security group for RDS from ECS"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = [var.cidr]
  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.rds_sg.this_security_group_id
    },
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = 6
      description              = "ECS Access to RDS"
      source_security_group_id = module.ecs_task_sg.this_security_group_id
    },
  ]

  number_of_computed_ingress_with_source_security_group_id = 2
  egress_cidr_blocks                                       = ["0.0.0.0/0"]
}

module "efs_sg" {
  source = "github.com/terraform-aws-modules/terraform-aws-security-group.git?ref=v3.18.0"

  name                = "efs_sg"
  description         = "Security group for EFS from ECS"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = [var.cidr]
  computed_ingress_with_source_security_group_id = [
    {
      from_port                = 2049
      to_port                  = 2049
      protocol                 = "tcp"
      description              = "ECS Access to EFS"
      source_security_group_id = module.ecs_task_sg.this_security_group_id
    },
  ]

  number_of_computed_ingress_with_source_security_group_id = 1
  egress_cidr_blocks                                       = ["0.0.0.0/0"]
}
