output "vpc_id" {
  value = module.network.vpc_id
}

output "azs" {
  value = module.network.azs
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "nat_public_ips" {
  value = module.network.nat_public_ips
}

output "asg_name" {
  value = module.compute.asg_name
}

output "web_security_group_id" {
  value = module.compute.security_group_id
}

output "ami_id" {
  value = module.compute.ami_id
}

output "list_instances" {
  description = "Command to list the web servers the ASG is running."
  value       = "aws ec2 describe-instances --filters Name=tag:aws:autoscaling:groupName,Values=${module.compute.asg_name} Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[InstanceId,Placement.AvailabilityZone,PrivateIpAddress]' --output table"
}
