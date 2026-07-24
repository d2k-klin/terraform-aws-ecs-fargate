variable "service_name" {
  description = "The name of the service (up to 255 letters, numbers, hyphens, and underscores)"
  default     = "noa-dev"
}
variable "ecs_cluster_arn" {
  description = "ARN of an ECS cluster"
}

variable "aws-region" {
  description = "AWS region"
}

variable "service_desired_count" {
  description = "Number of tasks running in parallel"
  default     = 2
}

variable "service_deployment_type" {
  default = "CODE_DEPLOY"
}

variable "security_group_ids" {
  type    = list(any)
  default = []
}

variable "subnet_ids" {
  type    = list(any)
  default = []
}

variable "alb_target_group_arn" {
  description = "The ARN of the Load Balancer target group to associate with the service."
}

variable "container_name" {
  description = "Docker image to be launched"
  default     = "noa-dev-container"
}

variable "container_port" {
  description = "The port where the Docker is exposed"
  default     = 5000
}

variable "container_log_level" {
  description = "The container log level"
  default     = "DEBUG"
}

variable "container_cpu" {
  description = "The number of cpu units used by the task"
  default     = 256
}

variable "container_memory" {
  description = "The amount (in MiB) of memory used by the task"
  default     = 512
}

variable "container_mount_path" {
  description = "Container path to mount EFS"
  default     = "db_folder"
}

variable "ecs_task_public_ip" {
  description = "Bool value to for Assigning Public IP to ECS Task"
  default     = false

}

variable "docker_image" {
  description = "Docker image + url(ex. ECR) to be launched"
}


variable "ecs_cluster_name" {
  description = "ECS cluster name required for resource_id in Service autoscaling configuration"
}

variable "lb_arn_suffix" {
  description = "ARN suffix of load balancer - required for resource_label for  Serviceautoscaling configuration"
}

variable "target_group_arn_suffixes" {
  description = "ARN suffix of target group - required for resource_label for  Serviceautoscaling configuration"
}

#Task Vars

variable "cw_arn" {
  description = "ARN of the cloudwatch log group"
}

variable "volume_name" {
  description = "The name of the volume. This name is referenced in the sourceVolume parameter of container definition in the mountPoints section."
  default     = "efs_mount"
}

variable "file_system_id" {
  description = "The ID of the EFS File System."
}

variable "tags" {
  description = "Key-value map of resource tags"

}