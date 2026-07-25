# =============================================================================
# examples/capstone — variables
# =============================================================================

variable "use_localstack" {
  description = "Point the AWS provider at LocalStack and skip real-cloud handshakes."
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region (LocalStack ignores it but the provider requires one)."
  type        = string
  default     = "us-east-1"
}

variable "state_passphrase" {
  description = "Passphrase for PBKDF2 state encryption. MUST be >= 16 chars. Set via TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
  # Workshop default only — supply via env in real use; never commit a real secret.
  default = "demo-state-passphrase-change-me"

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

# Optional explicit naming suffixes. Null → modules/naming generates a random
# 4-hex suffix (apply/integration). Unit plan tests pass fixed values so the
# composed name is known without apply.
variable "artifacts_suffix" {
  description = "Optional explicit suffix for the artifacts bucket name."
  type        = string
  default     = null
}

variable "index_suffix" {
  description = "Optional explicit suffix for the index table name."
  type        = string
  default     = null
}

variable "queue_suffix" {
  description = "Optional explicit suffix for the work queue name."
  type        = string
  default     = null
}
