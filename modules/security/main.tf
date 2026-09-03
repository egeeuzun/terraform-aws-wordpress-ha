locals {
  port_http      = 80
  port_https     = 443
  port_memcached = 11211
  port_nfs       = 2049
  port_mysql     = 3306
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB - HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.alb_ingress_prefix_list_ids) > 0 ? var.alb_origin_ports : []

    content {
      description     = "Web from CloudFront edge locations"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      prefix_list_ids = var.alb_ingress_prefix_list_ids
    }
  }

  dynamic "ingress" {
    for_each = length(var.alb_ingress_cidrs) > 0 ? [local.port_http, local.port_https] : []

    content {
      description = "Web from allowed CIDRs"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.alb_ingress_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_security_group" "cache" {
  name        = "${var.name}-cache-sg"
  description = "Memcached - only from ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Memcached from ECS"
    from_port       = local.port_memcached
    to_port         = local.port_memcached
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  dynamic "ingress" {
    for_each = length(var.vpn_sg_ids) > 0 ? [1] : []
    content {
      description     = "Memcached from VPN"
      from_port       = local.port_memcached
      to_port         = local.port_memcached
      protocol        = "tcp"
      security_groups = var.vpn_sg_ids
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-cache-sg" })
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs-sg"
  description = "ECS tasks - only from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  dynamic "ingress" {
    for_each = length(var.vpn_sg_ids) > 0 ? [1] : []
    content {
      description     = "HTTP from VPN"
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = var.vpn_sg_ids
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-ecs-sg" })
}

resource "aws_security_group" "efs" {
  name        = "${var.name}-efs-sg"
  description = "NFS - only from ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from ECS"
    from_port       = local.port_nfs
    to_port         = local.port_nfs
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  dynamic "ingress" {
    for_each = length(var.vpn_sg_ids) > 0 ? [1] : []
    content {
      description     = "NFS from VPN"
      from_port       = local.port_nfs
      to_port         = local.port_nfs
      protocol        = "tcp"
      security_groups = var.vpn_sg_ids
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-efs-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "MariaDB - only from ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MariaDB from ECS"
    from_port       = local.port_mysql
    to_port         = local.port_mysql
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  dynamic "ingress" {
    for_each = length(var.vpn_sg_ids) > 0 ? [1] : []
    content {
      description     = "MariaDB from VPN"
      from_port       = local.port_mysql
      to_port         = local.port_mysql
      protocol        = "tcp"
      security_groups = var.vpn_sg_ids
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-rds-sg" })
}
