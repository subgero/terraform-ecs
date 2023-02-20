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

resource "aws_vpc" "demo-vpc" {
  cidr_block = var.cidr_block
  instance_tenancy = "default"
  tags = {
    Name = var.name
  }
}


# resource "aws_ecs_cluster" "cluster" {
#   name = "nginx"

#   setting {
#     name  = "containerInsights"
#     value = "enabled"
#   }
# }