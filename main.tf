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

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.demo_vpc.id

  for_each = var.public_subnets

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.name}-rt"
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = "${var.name}-log-group"
}

resource "aws_ecs_cluster" "nginx_cluster" {
  name = var.name

  configuration {
    execute_command_configuration {
      logging    = "OVERRIDE"

      log_configuration {
        # cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      }
    }
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
      name      = "nginx"
      image     = var.image
      cpu       = 512
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

resource "aws_ecs_service" "nginx" {
  name            = var.name
  cluster         = aws_ecs_cluster.nginx_cluster.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1
  iam_role        = aws_iam_role.nginx_role.arn
  depends_on      = [aws_iam_role_policy.nginx_policy]
  launch_type     = "FARGATE"

  # network_configuration {
  #   security_groups = aws_security_group.sg_nginx.arn

  #   for_each = aws_subnet.public_subnet

  #   subnets = each.key
  # }

  # ordered_placement_strategy {
  #   type  = "binpack"
  #   field = "cpu"
  # }

  # load_balancer {
  #   target_group_arn = aws_lb_target_group.nginx_tg.arn
  #   container_name   = "nginx"
  #   container_port   = 80
  # }

  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  # }
}

resource "aws_lb" "nginx" {
  name               = "${var.name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_nginx.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]

  enable_deletion_protection = true

  tags = {
    Environment = "${var.name}_demo"
  }
}

resource "aws_lb_listener" "nginx-listener" {
  load_balancer_arn = aws_lb.nginx.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

resource "aws_lb_target_group" "nginx_tg" {
  name     = "${var.name}-lb-tg"
  port     = 80
  # target_type = "alb" 
  protocol = "HTTP"
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

  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}