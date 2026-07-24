resource "aws_efs_file_system" "this" {
  count = var.create_efs ? 1 : 0

  creation_token = "${local.name}-efs"
  encrypted      = true

  tags = merge(local.tags, { Name = "${local.name}-efs" })
}

resource "aws_efs_mount_target" "this" {
  count = var.create_efs ? length(module.vpc.private_subnets) : 0

  file_system_id  = aws_efs_file_system.this[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [module.efs_sg.id]
}

moved {
  from = aws_efs_file_system.this
  to   = aws_efs_file_system.this[0]
}
