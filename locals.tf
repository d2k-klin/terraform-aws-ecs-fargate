locals {
  account = data.aws_caller_identity.current.account_id

  name = "${var.name}-${var.environment}"
  tags = {
    Owner       = "user"
    Environment = "dev"
  }

}
