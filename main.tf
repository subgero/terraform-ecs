terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  shared_credentials_files = [
    "~/.aws/credentials"
  ]
  profile=var.profile
  region = var.region
}

resource "aws_vpc" "demo_vpc" {
  cidr_block = var.cidr_block
  instance_tenancy = "default"
  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "public_subnet" {

  for_each = var.public_subnets

  vpc_id                = aws_vpc.demo_vpc.id
  cidr_block            = each.value["cidr"]
  availability_zone_id  = each.value["az"]

  tags = {
    Name = "${var.name}-subnet-${each.key}"
  }
}

resource "aws_ecs_cluster" "nginx_cluster" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "nginx" {
  cpu                       = 1024
  family                    = "service"
  memory                    = 2048
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name      = "first"
      image     = var.image
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "nginx_service" {
  name            = var.name
  cluster         = aws_ecs_cluster.nginx_cluster.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 3
  iam_role        = aws_iam_role.nginx_role.arn
  depends_on      = [aws_iam_role_policy.nginx_policy]

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "mongo"
    container_port   = 8080
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}

resource "aws_lb" "test" {
  name               = "${var.name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_nginx.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]

  enable_deletion_protection = true

  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.id
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = {
    Environment = "${var.name}_demo"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.name}-lb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.demo_vpc.id
}

# permissions

resource "aws_iam_role" "nginx_role" {
  name = "${var.name}_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "${var.name}_role"
  }
}

resource "aws_iam_role_policy" "nginx_policy" {
  name = "${var.name}_policy"
  role = aws_iam_role.nginx_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_security_group" "sg_nginx" {

  egress {
    from_port        = 80
    to_port          = 80
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}