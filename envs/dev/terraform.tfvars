aws_region  = "us-east-2"
project     = "tflab"
environment = "dev"

vpc_cidr = "10.10.0.0/16"
az_count = 2

# NAT gateways bill by the hour. One shared NAT is plenty for dev.
enable_nat_gateway = true
single_nat_gateway = true
