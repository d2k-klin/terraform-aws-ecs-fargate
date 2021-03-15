locals {
  name = "noa-app"
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
