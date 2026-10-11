output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.web.name
}

output "security_group_id" {
  description = "Security group on the web instances. Phase 3 adds an ingress rule from the ALB to it."
  value       = aws_security_group.web.id
}

output "launch_template_id" {
  description = "ID of the launch template the ASG uses."
  value       = aws_launch_template.web.id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI the launch template currently points at."
  value       = data.aws_ssm_parameter.al2023.insecure_value
}

output "iam_role_name" {
  description = "IAM role attached to the instances."
  value       = aws_iam_role.web.name
}
