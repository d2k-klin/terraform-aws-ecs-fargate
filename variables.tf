variable "name" {
  description = "the name of your app, e.g. \"prod\""
  default     = "noa"
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
  default     = "dev"
}

variable "aws-region" {
  type        = string
  description = "AWS region to launch servers."
  default     = "eu-central-1"
}

variable "availability_zones" {
  description = "a comma-separated list of availability zones, defaults to all AZ of the region, if set to something other than the defaults, both private_subnets and public_subnets have to be defined as well"
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "cidr" {
  description = "The CIDR block for the VPC."
  default     = "10.1.0.0/16"
}

variable "private_subnets" {
  description = "a list of CIDRs for private subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "public_subnets" {
  description = "a list of CIDRs for public subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
}

variable "db_subnets" {
  description = "a list of CIDRs for public subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]
}

variable "create_postgresql" {
  description = "Boolean value for DB createtion"
  default     = false
}

variable "create_cdn" {
  description = "Boolean value for CloudFront createtion"
  default     = true
}

variable "container_image" {
  description = "Docker image to be launched"
  default     = "noa-dev"
}

variable "health_check_path" {
  description = "Http path for task health check"
  default     = "/ping"
}

variable "custom_header" {
  description = "Custom Header to be set in  CloudFront and ALB to limit the ALB access only from CDN"
  default     = "CustomHeaderString"
}
