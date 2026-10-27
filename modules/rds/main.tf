resource "aws_db_instance" "primary" {
  identifier = "${var.name}-db"
  engine     = "mariadb"

  engine_version = "11.8.8"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 5
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  multi_az               = var.multi_az
  availability_zone      = var.primary_availability_zone
  publicly_accessible    = false

  backup_retention_period = 7
  copy_tags_to_snapshot   = true
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(var.tags, {
    Name   = "${var.name}-db"
    Backup = "true"
  })

  lifecycle {
    precondition {
      condition     = !(var.multi_az && var.primary_availability_zone != null)
      error_message = "multi_az = true iken availability_zone sabitlenemez; standby'in yerlesimini AWS kendisi yapar. primary_availability_zone'u null birakin."
    }
  }
}

resource "aws_db_instance" "replica" {
  count               = var.create_read_replica ? 1 : 0
  identifier          = "${var.name}-db-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.instance_class

  storage_encrypted     = true
  max_allocated_storage = var.allocated_storage * 5

  vpc_security_group_ids = [var.rds_sg_id]
  availability_zone      = var.replica_availability_zone
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = merge(var.tags, { Name = "${var.name}-db-replica" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.data_subnet_ids

  tags = { Name = "${var.name}-db-subnets" }
}
