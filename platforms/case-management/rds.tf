resource "aws_db_subnet_group" "cases" {
  name       = "cases-prod"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name   = "cases-prod-rds"
  vpc_id = var.vpc_id
}

resource "aws_db_instance" "cases" {
  identifier              = "cases-prod"
  engine                  = "postgres"
  engine_version          = "14.12"
  instance_class          = "db.r6g.large"
  allocated_storage       = 200
  storage_encrypted       = false
  db_subnet_group_name    = aws_db_subnet_group.cases.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false
}
