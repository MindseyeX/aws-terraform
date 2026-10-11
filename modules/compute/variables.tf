variable "name" {
  description = "Name prefix applied to every resource in this module (e.g. \"tflab-dev\")."
  type        = string
}

variable "environment" {
  description = "Environment name, shown on the web page each instance serves."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the instances' security group in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the Auto Scaling Group spreads instances across (one per AZ)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Provide at least 2 subnets so instances span multiple Availability Zones."
  }
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is cheap and enough for nginx."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 8
}

variable "min_size" {
  description = "Minimum number of instances the ASG keeps running."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances the ASG may scale to."
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Number of instances to run right now. 2 = one per AZ."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Extra tags merged onto every resource (in addition to provider default_tags)."
  type        = map(string)
  default     = {}
}
