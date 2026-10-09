variable "aws_region" {
  description = "Region for the state bucket. Keep it the same as your environments."
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Short project name used as a prefix. Lowercase letters, numbers and hyphens only (S3 naming rules)."
  type        = string
  default     = "tflab"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project))
    error_message = "project must be 3-20 characters of lowercase letters, numbers or hyphens."
  }
}

variable "force_destroy" {
  description = "Allow destroying the bucket even when it still contains state files. true for sandboxes only."
  type        = bool
  default     = true
}
