locals {
  name = "case-doc-upload"
}

# --- Storage for uploaded documents ---
resource "aws_s3_bucket" "uploads" {
  bucket = "lumin-case-doc-uploads"

  versioning {
    enabled = true
  }
}

# --- Container registry ---
resource "aws_ecr_repository" "app" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"
}

# --- IAM ---
resource "aws_iam_role" "task" {
  name = "${local.name}-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "task" {
  name = "${local.name}-task"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:*"]
      Resource = "*"
    }]
  })
}

# --- Networking ---
resource "aws_security_group" "service" {
  name   = "${local.name}-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ECS ---
resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 4096
  memory                   = 16384
  execution_role_arn       = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name         = local.name
    image        = "123456789012.dkr.ecr.eu-west-2.amazonaws.com/case-doc-upload:latest"
    essential    = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "DB_HOST",       value = aws_db_instance.cases.address },
      { name = "DB_USER",       value = "doc_upload" },
      { name = "DB_PASSWORD",   value = "Lum1n-Upl0ads-2026!" },
      { name = "UPLOAD_BUCKET", value = aws_s3_bucket.uploads.bucket },
    ]
  }])
}

resource "aws_lb_target_group" "app" {
  name        = local.name
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = var.https_listener_arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/uploads/*"]
    }
  }
}

resource "aws_ecs_service" "app" {
  name            = local.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.name
    container_port   = 8080
  }
}
