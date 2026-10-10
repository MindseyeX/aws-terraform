aws_region  = "us-east-2"
project     = "tflab"
environment = "dev"

vpc_cidr = "10.10.0.0/16"
az_count = 2

# NAT gateways bill by the hour. One shared NAT is plenty for dev.
# The web servers need NAT: cloud-init installs nginx from the internet.
enable_nat_gateway = true
single_nat_gateway = true

# Web tier: one small instance per AZ.
instance_type        = "t3.micro"
asg_min_size         = 1
asg_max_size         = 3
asg_desired_capacity = 2
