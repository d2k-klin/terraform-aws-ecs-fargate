resource "aws_efs_file_system" "this" {
  creation_token = "${var.name}-efs"

  tags = local.tags
}

resource "aws_efs_mount_target" "this" {
  count          = length(module.vpc.private_subnets) > 0 ? length(module.vpc.private_subnets) : 0
  file_system_id = aws_efs_file_system.this.id
  subnet_id      = module.vpc.private_subnets[count.index]
  security_groups = [
    module.efs_sg.this_security_group_id
  ]
}

