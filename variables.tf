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

variable "vpc_azs" {
    type        = list(string)
    default     = ["us-east-1", "us-east-2"]
    description = "Availability zones for vpc"
}
variable "public_subnets" {
    type = list(string)
    default = ["10.0.10.0/24", "10.0.20.0/24"]
    description = "private subnets"
}