module "db_dev" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.0"

  create_db_instance = var.create_postgresql
  identifier         = "${local.name}-db"

  create_db_option_group    = false
  create_db_parameter_group = false

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  manage_master_user_password = true

  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [module.rds_sg.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  backup_retention_period = var.db_backup_retention_days
  skip_final_snapshot     = true

  tags = local.tags
}
