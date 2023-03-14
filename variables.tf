variable "profile" {
  type        = string
  default     = "default"
  description = "Name of the aws profile to deploy resources"
}

variable "name" {
  type        = string
  default     = "demo"
  description = "Name to be used on all the resources as identifier"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Region to deplay resources"
}

variable "cidr_block" {
    type        = string
    default     = "10.0.0.0/16"
    description = "The CIDR block for vpc"
}

variable "public_subnets" {
   type = map
   default = {
      sub-1 = {
         az = "use1-az1"
         cidr = "10.0.10.0/24"
      }
      sub-2 = {
         az = "use1-az2"
         cidr = "10.0.20.0/24"
      }
   }
}

variable "image" {
   type = string
   default = "nginx:alpine"
   description = "Name and version of the image for ecs service"
}