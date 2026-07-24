output "application_url" {
  description = "Public URL for the application."
  value = var.create_cdn ? "https://${module.cdn.cloudfront_distribution_domain_name}" : format(
    "%s://%s",
    var.certificate_arn == null ? "http" : "https",
    module.alb_ecs.dns_name
  )
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = module.alb_ecs.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name, or null when the CDN is disabled."
  value       = var.create_cdn ? module.cdn.cloudfront_distribution_domain_name : null
}

output "ecr_repository_url" {
  description = "Repository URL to which application images can be pushed."
  value       = aws_ecr_repository.main.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.fargate_ecs.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs_service.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logs group for container logs."
  value       = module.ecs_service.container_definitions["app"].cloudwatch_log_group_name
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "availability_zones" {
  description = "Availability Zones selected for this deployment."
  value       = module.vpc.azs
}

output "private_subnet_ids" {
  description = "IDs of the private ECS subnets."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public ALB subnets."
  value       = module.vpc.public_subnets
}

output "nat_public_ips" {
  description = "Public IP addresses of the NAT Gateways."
  value       = module.vpc.nat_public_ips
}

output "efs_file_system_id" {
  description = "EFS file system ID, or null when EFS is disabled."
  value       = var.create_efs ? aws_efs_file_system.this[0].id : null
}

output "database_endpoint" {
  description = "RDS endpoint, or null when PostgreSQL is disabled."
  value       = var.create_postgresql ? module.db_dev.db_instance_endpoint : null
}

output "database_master_secret_arn" {
  description = "Secrets Manager ARN for the RDS master credentials, or null when PostgreSQL is disabled."
  value       = var.create_postgresql ? module.db_dev.db_instance_master_user_secret_arn : null
  sensitive   = true
}
