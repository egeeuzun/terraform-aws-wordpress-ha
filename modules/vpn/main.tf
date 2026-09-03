locals {
  mongodb_version = "8.0"

  user_data = <<-BASH
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y curl gnupg ca-certificates

    curl -fsSL https://pgp.mongodb.com/server-${local.mongodb_version}.asc \
      | gpg --dearmor -o /usr/share/keyrings/mongodb-server-${local.mongodb_version}.gpg
    echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-${local.mongodb_version}.gpg ] https://repo.mongodb.org/apt/ubuntu ${var.ubuntu_codename}/mongodb-org/${local.mongodb_version} multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-${local.mongodb_version}.list

    PRITUNL_FPR=7568D9BB55FF9E5287D586017AE645C0CF8E292A
    curl -fsSL https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc \
      | gpg --dearmor -o /usr/share/keyrings/pritunl.gpg
    gpg --show-keys --with-colons /usr/share/keyrings/pritunl.gpg \
      | grep -q "^fpr:::::::::$PRITUNL_FPR:"

    echo "deb [ signed-by=/usr/share/keyrings/pritunl.gpg ] https://repo.pritunl.com/stable/apt ${var.ubuntu_codename} main" \
      > /etc/apt/sources.list.d/pritunl.list

    apt-get update
    apt-get install -y pritunl mongodb-org wireguard-tools

    systemctl enable --now mongod
    systemctl enable --now pritunl

    systemctl is-active --quiet mongod
    systemctl is-active --quiet pritunl
  BASH
}

data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_codename}-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "vpn" {
  name        = "${var.name}-vpn-sg"
  description = "Pritunl VPN - OpenVPN clients and admin console"
  vpc_id      = var.vpc_id

  ingress {
    description = "OpenVPN (UDP)"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = var.client_cidrs
  }

  ingress {
    description = "OpenVPN (TCP fallback)"
    from_port   = 1194
    to_port     = 1194
    protocol    = "tcp"
    cidr_blocks = var.client_cidrs
  }

  dynamic "ingress" {
    for_each = var.wireguard_port == null ? [] : [var.wireguard_port]
    content {
      description = "WireGuard"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = var.client_cidrs
    }
  }

  ingress {
    description = "Pritunl admin console"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  ingress {
    description = "ACME HTTP-01 challenge"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.acme_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-vpn-sg" }

  lifecycle {
    precondition {
      condition     = length(var.admin_cidrs) > 0 && !contains(var.admin_cidrs, "0.0.0.0/0")
      error_message = "vpn_admin_cidrs bos birakilamaz ve 0.0.0.0/0 olamaz: Pritunl yonetim konsolu internete tamamen acilmamali. Ofis/ev IP'nizi /32 olarak verin."
    }
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpn" {
  name               = "${var.name}-vpn-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = { Name = "${var.name}-vpn-role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.vpn.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vpn" {
  name = "${var.name}-vpn-profile"
  role = aws_iam_role.vpn.name
}

resource "aws_instance" "pritunl" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.vpn.id]
  iam_instance_profile   = aws_iam_instance_profile.vpn.name
  user_data              = local.user_data

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.name}-pritunl" }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "vpn" {
  domain   = "vpc"
  instance = aws_instance.pritunl.id

  tags = { Name = "${var.name}-pritunl-eip" }
}
