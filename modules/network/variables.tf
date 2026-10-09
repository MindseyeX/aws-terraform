variable "name" {
  description = "Name prefix applied to every resource in this module (e.g. \"tflab-dev\")."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Subnets are carved out of it automatically with cidrsubnet()."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "How many Availability Zones to spread subnets across. 2 is the minimum for an ALB."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so instances in private subnets can reach the internet (package installs, updates)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, fine for dev). false = one NAT per AZ (survives an AZ outage, production pattern)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto every resource (in addition to provider default_tags)."
  type        = map(string)
  default     = {}
}
