variable "name" {
  type        = string
  description = "Short project name used in AWS resource names."
  default     = "app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.name))
    error_message = "name must be 2-20 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment, for example dev, staging, or prod."
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.environment)) && length("${var.name}-${var.environment}") <= 32
    error_message = "environment must be 2-11 lowercase letters, numbers, or hyphens; the combined name-environment must be at most 32 characters."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region in which to create regional resources."
  default     = "us-east-1"
}

variable "availability_zone_count" {
  type        = number
  description = "Number of available AZs to discover when availability_zones is null."
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 6
    error_message = "availability_zone_count must be between 2 and 6."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Explicit AZs to use. Leave null to select available AZs in aws_region automatically."
  default     = null

  validation {
    condition     = var.availability_zones == null ? true : (length(var.availability_zones) >= 2 && length(var.availability_zones) <= 6)
    error_message = "availability_zones must contain between 2 and 6 AZs when set."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC. It must have room for generated subnets."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR with at least 8 bits available for subnetting."
  }
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet CIDRs. Leave null to derive one per selected AZ from vpc_cidr."
  default     = null

  validation {
    condition     = var.private_subnets == null ? true : length(var.private_subnets) == (var.availability_zones == null ? var.availability_zone_count : length(var.availability_zones))
    error_message = "private_subnets must contain one CIDR for every selected AZ."
  }
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDRs. Leave null to derive one per selected AZ from vpc_cidr."
  default     = null

  validation {
    condition     = var.public_subnets == null ? true : length(var.public_subnets) == (var.availability_zones == null ? var.availability_zone_count : length(var.availability_zones))
    error_message = "public_subnets must contain one CIDR for every selected AZ."
  }
}

variable "database_subnets" {
  type        = list(string)
  description = "Database subnet CIDRs. Leave null to derive one per selected AZ from vpc_cidr."
  default     = null

  validation {
    condition     = var.database_subnets == null ? true : length(var.database_subnets) == (var.availability_zones == null ? var.availability_zone_count : length(var.availability_zones))
    error_message = "database_subnets must contain one CIDR for every selected AZ."
  }
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use one NAT Gateway for lower cost. Set false for one per AZ and higher availability."
  default     = true
}

variable "allowed_ipv4_cidr_blocks" {
  type        = list(string)
  description = "IPv4 CIDRs allowed to reach the ALB when create_cdn is false. Ignored for a private CloudFront VPC origin."
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_ipv4_cidr_blocks) > 0 && alltrue([for cidr in var.allowed_ipv4_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "allowed_ipv4_cidr_blocks must contain at least one valid CIDR."
  }
}

variable "certificate_arn" {
  type        = string
  description = "Optional regional ACM certificate ARN for direct ALB HTTPS when create_cdn is false."
  default     = null

  validation {
    condition     = var.certificate_arn == null || !var.create_cdn
    error_message = "certificate_arn configures direct ALB HTTPS and cannot be set when create_cdn is true."
  }
}

variable "container_image" {
  type        = string
  description = "Complete container image reference. The public nginx image makes the first deployment immediately testable."
  default     = "public.ecr.aws/docker/library/nginx:alpine"
}

variable "container_port" {
  type        = number
  description = "Port on which the container listens."
  default     = 80

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "health_check_path" {
  type        = string
  description = "HTTP path used by the ALB health check."
  default     = "/"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must begin with /."
  }
}

variable "container_cpu" {
  type        = number
  description = "Fargate task CPU units."
  default     = 256
}

variable "container_memory" {
  type        = number
  description = "Fargate task memory in MiB."
  default     = 512
}

variable "container_environment" {
  type        = map(string)
  description = "Non-secret environment variables passed to the container."
  default     = {}
}

variable "container_secrets" {
  type        = map(string)
  description = "Container environment variable names mapped to Secrets Manager secret or SSM parameter ARNs."
  default     = {}
}

variable "task_policy_arns" {
  type        = set(string)
  description = "IAM policy ARNs to attach to the application task role."
  default     = []
}

variable "task_execution_policy_arns" {
  type        = set(string)
  description = "Extra IAM policy ARNs for image pulls, logs, and resolving container_secrets."
  default     = []
}

variable "service_desired_count" {
  type        = number
  description = "Initial number of running ECS tasks."
  default     = 1

  validation {
    condition     = var.service_desired_count >= var.autoscaling_min_capacity && var.service_desired_count <= var.autoscaling_max_capacity
    error_message = "service_desired_count must be between autoscaling_min_capacity and autoscaling_max_capacity."
  }
}

variable "autoscaling_min_capacity" {
  type        = number
  description = "Minimum ECS task count."
  default     = 1

  validation {
    condition     = var.autoscaling_min_capacity >= 1
    error_message = "autoscaling_min_capacity must be at least 1."
  }
}

variable "autoscaling_max_capacity" {
  type        = number
  description = "Maximum ECS task count."
  default     = 4

  validation {
    condition     = var.autoscaling_max_capacity >= var.autoscaling_min_capacity
    error_message = "autoscaling_max_capacity must be greater than or equal to autoscaling_min_capacity."
  }
}

variable "use_fargate_spot" {
  type        = bool
  description = "Run tasks on lower-cost interruptible Fargate Spot capacity."
  default     = true
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days."
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention period supported by CloudWatch Logs."
  }
}

variable "ecr_image_count" {
  type        = number
  description = "Number of container images retained in ECR."
  default     = 20

  validation {
    condition     = var.ecr_image_count >= 1
    error_message = "ecr_image_count must be at least 1."
  }
}

variable "create_efs" {
  type        = bool
  description = "Create and mount an encrypted EFS file system at container_mount_path."
  default     = false
}

variable "container_mount_path" {
  type        = string
  description = "Absolute container path at which to mount EFS when create_efs is true."
  default     = "/data"

  validation {
    condition     = startswith(var.container_mount_path, "/")
    error_message = "container_mount_path must be an absolute path."
  }
}

variable "create_cdn" {
  type        = bool
  description = "Create CloudFront with a VPC origin and move the ALB into private subnets."
  default     = false
}

variable "cloudfront_price_class" {
  type        = string
  description = "CloudFront price class."
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "cloudfront_geo_restriction_locations" {
  type        = list(string)
  description = "ISO 3166-1 country codes allowed by CloudFront. Empty means no geo restriction."
  default     = []
}

variable "create_postgresql" {
  type        = bool
  description = "Create an RDS PostgreSQL instance."
  default     = false
}

variable "db_name" {
  type        = string
  description = "Initial database name when create_postgresql is true."
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "RDS master username. The password is managed by AWS Secrets Manager."
  default     = "app_admin"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class when create_postgresql is true."
  default     = "db.t4g.micro"
}

variable "db_backup_retention_days" {
  type        = number
  description = "Days of automated RDS backups."
  default     = 7

  validation {
    condition     = var.db_backup_retention_days >= 0 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 0 and 35."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to all supported AWS resources."
  default     = {}
}
