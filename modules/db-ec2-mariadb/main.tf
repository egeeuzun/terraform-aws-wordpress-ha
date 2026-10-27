# Local Zone'da RDS olmadigi icin MariaDB bir EC2 instance'inda calisir.
#
# Veri ayri bir EBS diskinde (/var/lib/mysql). Instance degistirilebilir:
# yenisi ayni diski takar, veriyi bulur ve ayni sabit IP ile ayaga kalkar.
# Disk her gece Data Lifecycle Manager ile snapshot'lanir; snapshot'lar Local
# Zone'un kendisinde tutulur (Local Snapshots), parent region'a gitmez.
#
# RDS'in verdigi ama burada olmayanlar: otomatik failover, point-in-time
# restore, yonetilen surum guncellemesi. Tek instance tek nokta arizasidir
# (docs/adr/006-ec2-uzerinde-mariadb.md).

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

locals {
  # DLM bu etiketi tasiyan diskleri yedekler.
  snapshot_tag = { "lz-woo-snapshot" = "${var.name}-db" }

  # Nitro'da EBS diskleri NVMe olarak gorunur; /dev/sdf adi garanti degil,
  # seri numarasi (tiresiz volume id) ise sabit.
  data_device = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.data.id, "-", "")}"

  user_data = <<-BASH
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive

    DATA_DEV="${local.data_device}"

    apt-get update
    apt-get install -y mariadb-server openssl
    snap install aws-cli --classic
    systemctl stop mariadb

    # Veri diskini bekle (attachment instance'tan sonra olusur)
    for _ in $(seq 1 60); do
      [ -e "$DATA_DEV" ] && break
      sleep 5
    done
    [ -e "$DATA_DEV" ]

    # Bos disk: bicimlendir ve paketin olusturdugu bos veri dizinini tasi.
    # Dolu disk (instance degisimi): oldugu gibi kullan.
    if ! blkid "$DATA_DEV"; then
      mkfs.ext4 -L mariadb-data "$DATA_DEV"
    fi
    mkdir -p /mnt/mariadb-data
    mount "$DATA_DEV" /mnt/mariadb-data
    if [ ! -d /mnt/mariadb-data/mysql ]; then
      cp -a /var/lib/mysql/. /mnt/mariadb-data/
    fi
    umount /mnt/mariadb-data

    DATA_UUID=$(blkid -s UUID -o value "$DATA_DEV")
    grep -q "$DATA_UUID" /etc/fstab \
      || echo "UUID=$DATA_UUID /var/lib/mysql ext4 defaults,nofail,noatime 0 2" >> /etc/fstab
    mount /var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql

    # RDS gibi yalnizca TLS'li baglanti. Imaj sunucu sertifikasini dogrulamiyor,
    # bu yuzden self-signed sertifika yeterli.
    install -d -o mysql -g mysql -m 0750 /etc/mysql/ssl
    if [ ! -f /etc/mysql/ssl/server-key.pem ]; then
      openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj "/CN=${var.name}-db" \
        -keyout /etc/mysql/ssl/server-key.pem \
        -out /etc/mysql/ssl/server-cert.pem
      chown mysql:mysql /etc/mysql/ssl/server-*.pem
      chmod 0600 /etc/mysql/ssl/server-key.pem
    fi

    # Bellegin yarisi InnoDB buffer pool'a
    MEM_MB=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
    cat > /etc/mysql/mariadb.conf.d/90-${var.name}.cnf <<CNF
    [mariadbd]
    bind-address             = 0.0.0.0
    skip-name-resolve
    require_secure_transport = ON
    ssl_cert                 = /etc/mysql/ssl/server-cert.pem
    ssl_key                  = /etc/mysql/ssl/server-key.pem
    innodb_buffer_pool_size  = $((MEM_MB / 2))M
    max_connections          = 200
    CNF

    systemctl enable mariadb
    systemctl start mariadb

    DB_PASSWORD=$(/snap/bin/aws ssm get-parameter --region ${data.aws_region.current.name} \
      --name "${var.db_password_ssm_name}" --with-decryption \
      --query Parameter.Value --output text)

    mariadb <<SQL
    CREATE DATABASE IF NOT EXISTS \`${var.db_name}\`;
    CREATE USER IF NOT EXISTS '${var.db_username}'@'%' IDENTIFIED BY '$DB_PASSWORD' REQUIRE SSL;
    ALTER USER '${var.db_username}'@'%' IDENTIFIED BY '$DB_PASSWORD' REQUIRE SSL;
    GRANT ALL PRIVILEGES ON \`${var.db_name}\`.* TO '${var.db_username}'@'%';
    FLUSH PRIVILEGES;
    SQL
  BASH
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "db" {
  name               = "${var.name}-db-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Bakim (paket guncellemesi, mysqldump) SSH yerine Session Manager ile.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.db.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "db_password" {
  name = "${var.name}-db-password-read"
  role = aws_iam_role.db.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = [var.db_password_ssm_arn]
    }]
  })
}

resource "aws_iam_instance_profile" "db" {
  name = "${var.name}-db-profile"
  role = aws_iam_role.db.name
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.local_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, local.snapshot_tag, { Name = "${var.name}-db-data" })
}

resource "aws_instance" "db" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.db.name
  user_data              = local.user_data

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
    tags        = merge(var.tags, { Name = "${var.name}-db-root" })
  }

  tags = merge(var.tags, { Name = "${var.name}-db" })

  # user_data yalnizca ilk acilista calisir; degisince instance'i durdurup
  # baslatmak bir sey kazandirmaz. Yeni AMI/user_data icin: terraform apply
  # -replace=module.db.aws_instance.db (veri diski korunur).
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.db.id

  # MariaDB disk altindan cekilmeden kapansin
  stop_instance_before_detaching = true
}

# --- Yerel snapshot'lar -------------------------------------------------------

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  name               = "${var.name}-dlm-role"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "db" {
  description        = "${var.name} MariaDB data volume - local snapshots"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    policy_type        = "EBS_SNAPSHOT_MANAGEMENT"
    resource_types     = ["VOLUME"]
    resource_locations = ["LOCAL_ZONE"]
    target_tags        = local.snapshot_tag

    schedule {
      name      = "daily-local"
      copy_tags = true

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = [var.snapshot_time_utc]
        # Snapshot Local Zone'da kalir. CLOUD olsaydi parent region'a
        # (Frankfurt) yazilirdi.
        location = "LOCAL_ZONE"
      }

      retain_rule {
        count = var.snapshot_retention_count
      }
    }
  }

  tags = { Name = "${var.name}-db-snapshots" }
}
