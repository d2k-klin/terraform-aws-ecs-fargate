# terraform-aws-ecs-fargate

A ready-to-fork Terraform starter for running a containerized app on **AWS ECS
Fargate**, fronted by an **Application Load Balancer** and (optionally)
**CloudFront**, with **ECR** for images, **EFS** for shared storage, and an
**optional RDS PostgreSQL** database.

It's meant as a **jump start for small projects**: clone it, point it at your
container image, `terraform apply`, and you have a scalable, load-balanced
service running on serverless containers. Everything is wired together with
sensible defaults and the official
[terraform-aws-modules](https://github.com/terraform-aws-modules), so you can
grow into it rather than out of it.

![Architecture Diagram](/images/architecture-diagram.png)

## What it creates

- **VPC** — 3 public + 3 private + 3 database subnets across 3 AZs, an Internet
  Gateway, and a single NAT Gateway (cheapest option for a small project).
- **Security groups** — least-privilege: public HTTP on the ALB, container port
  reachable only from the ALB, EFS/RDS reachable only from the ECS tasks.
- **Application Load Balancer** — HTTP listener on `:80`, plus a secondary
  listener on `:8080` for blue/green deployments via CodeDeploy.
- **ECR repository** — with a lifecycle policy that keeps the last 10 images.
- **ECS cluster (Fargate)** — Container Insights on, FARGATE + FARGATE_SPOT
  capacity providers (SPOT-first to save money).
- **ECS service + task** — defined in the reusable `modules/ecs-noa` module,
  including CPU / memory / ALB-request autoscaling and the task execution IAM
  role. Add more services by copying this module and referencing it in
  `main.tf`.
- **EFS** — shared file system mounted into every task.
- **CloudFront** *(optional)* — CDN in front of the ALB, locked to it via a
  custom header.
- **RDS PostgreSQL** *(optional)* — with the master password managed in AWS
  Secrets Manager.

## Requirements

| Tool | Version |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | >= 1.5 (>= 1.11 for S3 native state locking) |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 |
| AWS provider | ~> 6.0 (pinned in `versions.tf`) |
| An AWS account | with credentials configured (`aws configure`) |

## Module versions

All community modules are pinned in the `.tf` files:

| Module | Version |
|--------|---------|
| terraform-aws-modules/vpc/aws | ~> 6.0 |
| terraform-aws-modules/alb/aws | ~> 10.0 |
| terraform-aws-modules/ecs/aws (cluster) | ~> 7.0 |
| terraform-aws-modules/rds/aws | ~> 7.0 |
| terraform-aws-modules/cloudfront/aws | ~> 6.0 |
| terraform-aws-modules/security-group/aws | ~> 6.0 |

## Quick start

```bash
# 1. Clone
git clone https://github.com/<you>/terraform-aws-ecs-fargate.git
cd terraform-aws-ecs-fargate

# 2. Configure AWS credentials (if you haven't already)
aws configure

# 3. Initialize (uses local state until you configure a remote backend)
terraform init

# 4. Review the plan
terraform plan -out=out.plan

# 5. Apply
terraform apply out.plan
```

Terraform runs against the region in `var.aws-region` (default
`eu-central-1`). Override any variable on the CLI (`-var`), in a
`terraform.tfvars` file, or via `TF_VAR_*` environment variables.

### Deploy your image

ECS pulls from the ECR repository this stack creates. Build and push your
container, then re-apply (or let your CI redeploy the service):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=eu-central-1
REPO=noa-dev            # matches var.name-var.environment

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

docker build -t $REPO .
docker tag  $REPO:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:latest
```

Your app must listen on `var.container_port` (default `5000`) and answer the
health check at `var.health_check_path` (default `/ping`).

## Key variables

Full list in [`variables.tf`](variables.tf). The ones you'll most likely change:

| Variable | Default | Description |
|----------|---------|-------------|
| `name` / `environment` | `noa` / `dev` | Name prefix for all resources |
| `aws-region` | `eu-central-1` | Region to deploy into |
| `cidr` | `10.1.0.0/16` | VPC CIDR |
| `container_image` | `noa-dev` | ECR image tag ECS runs |
| `container_port` | `5000` | Port your container listens on |
| `health_check_path` | `/ping` | ALB health check path |
| `create_cdn` | `true` | Create the CloudFront distribution |
| `create_postgresql` | `false` | Create the RDS PostgreSQL instance |
| `db_name` / `db_username` | `appdb` / `app_user` | RDS DB name and master user (password is auto-managed in Secrets Manager) |

> **Heads up:** CloudFront geo-restriction defaults to whitelisting `DE` only
> (see `cloudfront.tf`). Change `locations` for your audience.

## Remote state backend

Local state is fine for trying things out, but for real use store state in S3.
`backend.tf` ships commented out with placeholder values — create a bucket,
fill it in, uncomment, and re-run `terraform init`.

<details>
<summary>Create an S3 state bucket</summary>

```bash
REGION=eu-central-1
BUCKET=my-terraform-state-$(aws sts get-caller-identity --query Account --output text)

aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Then set `bucket = "<BUCKET>"` in `backend.tf` and `terraform init` (it will
offer to migrate local state). `use_lockfile = true` uses S3-native state
locking, so no DynamoDB table is needed (Terraform >= 1.11).
</details>

## Adding another service

The ECS service/task lives in the reusable [`modules/ecs-noa`](modules/ecs-noa)
module. To run a second container, add another block in `main.tf`:

```hcl
module "ecs_service_worker" {
  source = "./modules/ecs-noa"

  service_name         = "worker"
  ecs_cluster_arn      = module.fargate_ecs.arn
  ecs_cluster_name     = module.fargate_ecs.name
  security_group_ids   = [module.ecs_task_sg.id]
  subnet_ids           = module.vpc.private_subnets
  alb_target_group_arn = module.alb_ecs.target_groups["primary"].arn
  # ... see main.tf for the full set of inputs
}
```

## Clean up

```bash
terraform destroy
```

## License

[MIT](LICENSE)
