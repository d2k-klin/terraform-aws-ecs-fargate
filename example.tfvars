# Copy to terraform.tfvars and edit. Run with: terraform apply -var-file=example.tfvars
name              = "noa"
environment       = "dev"
aws-region        = "eu-central-1"
container_image   = "noa-dev"
container_port    = 5000
health_check_path = "/ping"

# Optional add-ons
create_cdn        = true
create_postgresql = false
