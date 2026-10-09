output "state_bucket" {
  description = "Name of the remote state bucket."
  value       = aws_s3_bucket.state.bucket
}

output "next_step" {
  description = "What to run next."
  value       = "envs/dev/backend.hcl written. Now: cd ../envs/dev && terraform init -backend-config=backend.hcl"
}
