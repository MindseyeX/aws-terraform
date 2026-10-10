provider "aws" {
  region = var.aws_region

  # Every resource gets these tags automatically - no need to repeat them.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "${var.project}-${var.environment}"
}

# --- Phase 1: networking ------------------------------------------------------

module "network" {
  source = "../../modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}

# --- Phase 2: compute -----------------------------------------------------------
# Outputs of one module become inputs of the next - this is how Terraform
# knows to build the network before the servers that live in it.

module "compute" {
  source = "../../modules/compute"

  name        = local.name
  environment = var.environment
  vpc_id      = module.network.vpc_id
  subnet_ids  = module.network.private_subnet_ids

  instance_type    = var.instance_type
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
}
