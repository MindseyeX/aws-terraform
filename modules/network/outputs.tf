output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability Zones in use."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by AZ. Use for the ALB."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered by AZ. Use for the ASG and RDS."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateway(s) - the source IP your private instances appear as on the internet."
  value       = [for eip in aws_eip.nat : eip.public_ip]
}
