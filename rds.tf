################################################################################
# RDS Module (optional - toggle with var.create_postgresql)
################################################################################

module "db_dev" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.0"

  create_db_instance = var.create_postgresql
  identifier         = "${local.name}-db"

  create_db_option_group    = false
  create_db_parameter_group = false

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16" # DB parameter group
  major_engine_version = "16"         # DB option group
  instance_class       = "db.t4g.micro"

  allocated_storage = 20

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  # Master password is generated and stored in AWS Secrets Manager (no secret in code).
  # Retrieve it from the secret referenced by module.db_dev.db_instance_master_user_secret_arn.
  manage_master_user_password = true

  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [module.rds_sg.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  backup_retention_period = 0

  tags = local.tags

  depends_on = [module.vpc]
}
