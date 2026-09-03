resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 33
    gid = 33
  }

  root_directory {
    path = "/uploads"
    creation_info {
      owner_uid   = 33
      owner_gid   = 33
      permissions = "0755"
    }
  }

  tags = { Name = "${var.name}-uploads-ap" }
}

resource "aws_efs_access_point" "plugins" {
  count          = var.shared_code_dirs ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 33
    gid = 33
  }

  root_directory {
    path = "/plugins"
    creation_info {
      owner_uid   = 33
      owner_gid   = 33
      permissions = "0755"
    }
  }

  tags = { Name = "${var.name}-plugins-ap" }
}

resource "aws_efs_access_point" "themes" {
  count          = var.shared_code_dirs ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 33
    gid = 33
  }

  root_directory {
    path = "/themes"
    creation_info {
      owner_uid   = 33
      owner_gid   = 33
      permissions = "0755"
    }
  }

  tags = { Name = "${var.name}-themes-ap" }
}

resource "aws_efs_file_system" "this" {
  creation_token = "${var.name}-efs"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name   = "${var.name}-efs"
    Backup = "true"
  }
}

resource "aws_efs_mount_target" "this" {
  count           = length(var.data_subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.data_subnet_ids[count.index]
  security_groups = [var.efs_sg_id]
}
