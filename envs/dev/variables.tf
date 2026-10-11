variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "project" {
  description = "Short project name, used as a prefix on resource names."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, ...)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to use."
  type        = number
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) for private subnet egress."
  type        = bool
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ."
  type        = bool
}

variable "instance_type" {
  description = "EC2 instance type for the web servers."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of web servers."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of web servers."
  type        = number
}

variable "asg_desired_capacity" {
  description = "Number of web servers to run."
  type        = number
}
