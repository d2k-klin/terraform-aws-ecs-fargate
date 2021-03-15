locals {
  account = data.aws_caller_identity.current.account_id

  name = "${var.name}-${var.environment}"
  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  container_environment_vars = [
    { name = "LOG_LEVEL",
    value = var.container_log_level },
    { name = "PORT",
    value = var.container_port }
  ]
}
