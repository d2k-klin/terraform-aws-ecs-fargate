# Copy this file to terraform.tfvars and change at least name and aws_region.
name        = "myapp"
environment = "dev"
aws_region  = "eu-west-1"

# The defaults deploy a public nginx container on port 80. Replace these after
# pushing your own image; see docs/USER_GUIDE.md.
container_image       = "public.ecr.aws/docker/library/nginx:alpine"
container_port        = 80
health_check_path     = "/"
service_desired_count = 1

container_environment = {
  APP_ENV = "development"
}

# Cost-first defaults. Review these before production.
availability_zone_count = 2
single_nat_gateway      = true
use_fargate_spot        = true

# Optional add-ons.
create_cdn        = false
create_efs        = false
create_postgresql = false

tags = {
  Owner      = "platform-team"
  CostCenter = "engineering"
}
