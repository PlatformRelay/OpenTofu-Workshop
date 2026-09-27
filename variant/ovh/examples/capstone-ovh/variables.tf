variable "cloud_region" {
  description = "OVH S3 region code, e.g. gra, sbg."
  type        = string
  default     = "gra"
}

variable "s3_access_key" {
  description = "OVH S3 access key. Null falls back to AWS_ACCESS_KEY_ID."
  type        = string
  default     = null
  sensitive   = true
}

variable "s3_secret_key" {
  description = "OVH S3 secret key. Null falls back to AWS_SECRET_ACCESS_KEY."
  type        = string
  default     = null
  sensitive   = true
}

variable "state_passphrase" {
  description = "Passphrase for PBKDF2 state encryption. MUST be >= 16 chars. Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
  # No default: a passphrase committed to the repo protects nothing. Export
  # TF_VAR_state_passphrase before the first tofu command.

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must be at least 16 characters (PBKDF2 requirement)."
  }
}

variable "project" {
  description = "Project slug used for naming + the project label."
  type        = string
  default     = "colony"
}

variable "environment" {
  description = "Environment used for naming + the environment label."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owning team email for the owner label."
  type        = string
  default     = "platform-team@example.com"
}

variable "cost_center" {
  description = "Cost centre for chargeback."
  type        = string
  default     = "CC-2600"
}

variable "artifacts_suffix" {
  description = "Optional explicit suffix for the artifacts bucket; null generates a random one."
  type        = string
  default     = null
}

variable "archive_suffix" {
  description = "Optional explicit suffix for the archive bucket; null generates a random one."
  type        = string
  default     = null
}
