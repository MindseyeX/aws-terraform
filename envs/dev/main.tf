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

# --- Phase 2: compute (coming next) -------------------------------------------
# module "compute" {
#   source             = "../../modules/compute"
#   name               = local.name
#   vpc_id             = module.network.vpc_id
#   public_subnet_ids  = module.network.public_subnet_ids
#   private_subnet_ids = module.network.private_subnet_ids
# }
