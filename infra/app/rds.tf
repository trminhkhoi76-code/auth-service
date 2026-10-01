resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "this" {
  identifier = "${local.name}-mysql"

  engine                     = "mysql"
  engine_version             = var.db_engine_version
  auto_minor_version_upgrade = true
  instance_class             = var.db_instance_class

  storage_type          = "gp3"
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_encrypted     = true

  db_name             = var.db_name
  username            = var.db_username
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = var.db_password_version

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  # UTC; 03:00-04:00 / Sun 04:00-05:00 JST
  backup_retention_period = var.db_backup_retention_days
  backup_window           = "18:00-19:00"
  maintenance_window      = "sat:19:00-sat:20:00"
  copy_tags_to_snapshot   = true

  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = "${local.name}-mysql-final"
  apply_immediately         = var.environment != "prod"
}
