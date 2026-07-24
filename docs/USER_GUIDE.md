# Developer user guide

This guide takes a new project from an empty AWS account workflow to a running
application on ECS Fargate. Commands assume a POSIX-compatible shell.

## 1. Understand the deployment

Traffic follows this path:

```text
Internet → optional CloudFront VPC origin → Application Load Balancer
         → ECS tasks in private subnets → optional RDS/EFS
```

ECS tasks have no public IP address. They pull images and reach external
services through a NAT Gateway. Security groups allow only the ALB to reach the
container port, and only ECS tasks to reach optional PostgreSQL and EFS.
When CloudFront is enabled, the ALB also moves into private subnets and accepts
origin traffic only from CloudFront's AWS-managed prefix list.

The default deployment is intended for development:

- two Availability Zones
- one NAT Gateway
- one Fargate Spot task
- no CDN, database, or shared file system
- a public nginx bootstrap image

## 2. Install prerequisites

Install:

1. Terraform `1.11.1` or newer, but below `2.0.0`
2. AWS CLI v2
3. Git
4. Docker only if you will build an application image locally

Verify the tools:

```bash
terraform version
aws --version
git --version
docker version # Optional
```

You also need an AWS account and credentials allowed to manage VPC, EC2
networking, ELB, ECS, ECR, IAM, CloudWatch Logs, Application Auto Scaling, and
any optional services you enable.

### Configure AWS authentication

Use your organization's preferred short-lived credentials. Common choices are:

```bash
# AWS IAM Identity Center / SSO
aws configure sso
aws sso login --profile my-profile
export AWS_PROFILE=my-profile

# Or a standard named profile
aws configure --profile my-profile
export AWS_PROFILE=my-profile
```

Confirm the account before every first apply:

```bash
aws sts get-caller-identity
```

The returned account ID and ARN must be the account you intend to change.

## 3. Create and configure your project

Select **Use this template** on GitHub and create a repository in your own
account or organization. This gives the project a clean history and a remote
that your team controls. With the GitHub CLI, the equivalent is:

```bash
gh repo create payments-infrastructure \
  --template d2k-klin/terraform-aws-ecs-fargate \
  --clone
cd payments-infrastructure
cp example.tfvars terraform.tfvars
```

If you use the GitHub website instead, clone the repository it created and then
copy `example.tfvars`.

`terraform.tfvars` is ignored by Git because it may eventually contain private
values. Do not put passwords or API keys in it.

At minimum, edit:

```hcl
name        = "payments"
environment = "dev"
aws_region  = "eu-west-1"

tags = {
  Owner      = "payments-team"
  CostCenter = "engineering"
}
```

The stack discovers available AZs in the chosen region and derives non-overlapping
subnets from `vpc_cidr`. To use existing network allocations, provide explicit
AZ and subnet lists:

```hcl
availability_zones = ["eu-west-1a", "eu-west-1b"]
private_subnets     = ["10.20.1.0/24", "10.20.2.0/24"]
public_subnets      = ["10.20.11.0/24", "10.20.12.0/24"]
database_subnets    = ["10.20.21.0/24", "10.20.22.0/24"]
```

Each subnet list must contain exactly one CIDR per selected AZ.

## 4. Initialize, review, and deploy

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=out.plan
terraform apply out.plan
```

Always read the plan. In particular, confirm:

- the AWS region and account
- resource names and tags
- the number of NAT Gateways and ECS tasks
- whether optional RDS, EFS, or CloudFront resources are enabled

Open the bootstrap application:

```bash
terraform output -raw application_url
```

It can take several minutes for the ALB target to become healthy. Check the ECS
service and target health in the AWS console if the URL initially returns an
error.

## 5. Build and publish your image

The first apply creates the ECR repository while ECS runs a public nginx image.
After that apply:

```bash
AWS_REGION="eu-west-1"
ECR_URL="$(terraform output -raw ecr_repository_url)"
ECR_REGISTRY="${ECR_URL%/*}"
IMAGE_TAG="$(git rev-parse --short HEAD)"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build -t "$ECR_URL:$IMAGE_TAG" .
docker push "$ECR_URL:$IMAGE_TAG"
```

On Apple Silicon, build for the task architecture if your image or base image
is not multi-platform:

```bash
docker buildx build --platform linux/amd64 \
  -t "$ECR_URL:$IMAGE_TAG" --push .
```

Update `terraform.tfvars`:

```hcl
container_image   = "<AWS_ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/payments-dev:a1b2c3d"
container_port    = 3000
health_check_path = "/health"
```

Your process must listen on `0.0.0.0`, not only `localhost`, and the health path
must return an HTTP `200`. Apply the change:

```bash
terraform plan -out=out.plan
terraform apply out.plan
```

Terraform creates a new task definition revision. ECS performs a rolling
deployment and automatically rolls back a failed deployment.

## 6. Configure the application

### Plain environment variables

```hcl
container_environment = {
  APP_ENV   = "production"
  LOG_LEVEL = "info"
}
```

These values are stored in Terraform state and the ECS task definition. Do not
use this input for secrets.

### Secrets Manager and Parameter Store values

Map the environment variable name to a Secrets Manager secret ARN or SSM
parameter ARN:

```hcl
container_secrets = {
  API_TOKEN = "arn:aws:secretsmanager:eu-west-1:<AWS_ACCOUNT_ID>:secret:api-token-AbCd"
}
```

The ECS agent resolves these values before starting the container. Full Secrets
Manager and SSM parameter ARNs are automatically added to the execution role by
the official ECS service module. Add an extra policy only when the secret needs
additional permissions, such as access to a customer-managed KMS key:

```hcl
task_execution_policy_arns = [
  "arn:aws:iam::<AWS_ACCOUNT_ID>:policy/payments-dev-secret-kms"
]
```

Application calls to AWS APIs use the separate task role:

```hcl
task_policy_arns = [
  "arn:aws:iam::<AWS_ACCOUNT_ID>:policy/payments-dev-application"
]
```

Create application-specific policies outside this starter and avoid broad
managed policies.

## 7. Enable optional components

### Direct HTTPS on the load balancer

Request or import an ACM certificate in the same region as the ALB, validate it,
then set the following when `create_cdn = false`:

```hcl
certificate_arn = "arn:aws:acm:eu-west-1:<AWS_ACCOUNT_ID>:certificate/..."
```

The port 80 listener will redirect to HTTPS. Create your DNS alias record to the
`alb_dns_name` output. DNS zone ownership is intentionally outside this stack.
When CloudFront is enabled, TLS terminates at CloudFront and the private VPC
origin uses HTTP to the internal ALB, so do not set `certificate_arn`.

### CloudFront

```hcl
create_cdn            = true
cloudfront_price_class = "PriceClass_100"
```

CloudFront provides HTTPS on its generated domain and uses a VPC origin to reach
an internal ALB in the private subnets. The ALB is no longer reachable directly
from the public internet. Its security group permits port 80 only from the
AWS-managed `com.amazonaws.global.cloudfront.origin-facing` prefix list.

The default behavior sends all paths to the same container, allows every common
HTTP method, forwards headers, cookies, and query strings, and disables caching.
This works for an application where one container serves both UI and API. Add
an explicit cached behavior later only for paths whose responses are genuinely
safe to cache.

VPC origins require a supported commercial AWS Region, an internet gateway
attached to the VPC, and available private IPv4 addresses for CloudFront's
service-managed network interfaces. The internet gateway marks the VPC as
internet-capable but is not used to route origin traffic. VPC origins do not
support gRPC or Lambda@Edge origin request/response triggers. Check the
[current AWS VPC-origin prerequisites and Region list](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html)
before enabling this option.

CloudFront has no country restriction by default. To allow selected countries:

```hcl
cloudfront_geo_restriction_locations = ["DE", "FR", "NL"]
```

### Shared EFS storage

```hcl
create_efs           = true
container_mount_path = "/data"
```

EFS is encrypted and mounted in every task. Use it only when tasks genuinely
need a shared POSIX file system; object storage is usually a simpler fit for
uploads and static assets.

### PostgreSQL

```hcl
create_postgresql       = true
db_name                 = "payments"
db_username             = "payments_admin"
db_instance_class       = "db.t4g.micro"
db_backup_retention_days = 7
```

RDS creates and stores the master password in Secrets Manager. Retrieve its ARN:

```bash
terraform output database_master_secret_arn
terraform output -raw database_endpoint
```

The database is reachable only from the ECS task security group. Enabling RDS
does not automatically inject connection settings into the container; wire the
managed secret or application-specific credentials through `container_secrets`.

## 8. Configure remote Terraform state

Local state is acceptable for a throwaway experiment. Teams and durable
environments should use encrypted, versioned remote state with locking.

Create a globally unique S3 bucket. For regions other than `us-east-1`:

```bash
STATE_REGION="eu-west-1"
STATE_BUCKET="my-company-terraform-state-<AWS_ACCOUNT_ID>"

aws s3api create-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$STATE_REGION" \
  --create-bucket-configuration LocationConstraint="$STATE_REGION"

aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

For `us-east-1`, omit `--create-bucket-configuration`. S3 encrypts new objects
by default; use your organization's KMS policy if customer-managed keys are
required.

Uncomment the S3 backend block in `backend.tf`, set its bucket, key, and region,
then migrate:

```bash
terraform init -migrate-state
```

`use_lockfile = true` enables S3-native state locking and requires Terraform
`1.11` or newer. Never share a state key between environments.

## 9. Prepare for production

Review these settings rather than copying development defaults unchanged:

```hcl
single_nat_gateway       = false
use_fargate_spot         = false
service_desired_count    = 2
autoscaling_min_capacity = 2
autoscaling_max_capacity = 10
log_retention_days       = 90
create_cdn               = true
```

Then add the controls appropriate to your organization:

- HTTPS and DNS
- remote state, CI plan/apply approvals, and separate AWS accounts
- CloudWatch alarms, dashboards, and centralized logs
- AWS WAF or another edge protection layer
- RDS Multi-AZ, deletion protection, and tested restore procedures
- multiple NAT Gateways or VPC endpoints according to availability and cost
- Fargate on-demand capacity for workloads that cannot tolerate interruption
- narrowly scoped task and deployment IAM policies
- container vulnerability and dependency remediation

## 10. Upgrade safely

Modules are pinned to reviewed versions and the provider lock file records the
provider selections. To inspect available updates:

```bash
terraform init -upgrade
terraform validate
terraform plan
git diff -- .terraform.lock.hcl
```

Read upstream changelogs before accepting a new major version. Commit the lock
file so every developer and CI uses the same provider selections.

### Upgrading from v1

In v2, `create_cdn = true` changes the ALB from internet-facing/public subnets
to internal/private subnets and replaces the public CloudFront custom origin
with a VPC origin. Expect Terraform to replace the ALB. Schedule the change
carefully for an existing application, confirm that its Region and selected
Availability Zones support VPC origins, and test the CloudFront URL before
removing any old DNS path.

### Existing repository users

This generalized version renamed several inputs:

| Previous input | Current input |
|---|---|
| `aws-region` | `aws_region` |
| `cidr` | `vpc_cidr` |
| `db_subnets` | `database_subnets` |

It also changed the default project name, container, port, health check, and
optional component defaults. Existing users should explicitly preserve their
current values before planning. Set `create_efs = true` before upgrading if the
old stack already manages EFS. Inspect the entire plan for replacement actions.

## 11. Troubleshoot

### Tasks repeatedly stop

Inspect stopped-task reasons and container logs:

```bash
CLUSTER="$(terraform output -raw ecs_cluster_name)"
SERVICE="$(terraform output -raw ecs_service_name)"

aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE"
aws logs tail "$(terraform output -raw cloudwatch_log_group_name)" --follow
```

Common causes are a wrong image architecture, missing secret permissions, the
process binding only to localhost, or an incorrect port.

### ALB reports unhealthy targets

Confirm the application listens on `container_port` and returns `200` from
`health_check_path`. The service allows 60 seconds of health-check grace time.

### Image cannot be pulled

Confirm the tag exists, the image URI and region are correct, NAT egress works,
and the task execution role has any extra registry or KMS permissions required.

### Terraform cannot load provider plugins

Reinitialize the working directory:

```bash
terraform init -upgrade
terraform validate
```

If a cached provider binary is for the wrong platform, remove only the local
`.terraform` working directory and run `terraform init` again. Do not remove
state files.

## 12. Clean up

```bash
terraform plan -destroy -out=destroy.plan
terraform apply destroy.plan
```

The ECR repository must be empty before AWS allows Terraform to delete it.
Retained external items such as manually created images, secrets, DNS records,
or the remote-state bucket require separate cleanup.
