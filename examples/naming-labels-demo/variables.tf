# =============================================================================
# examples/naming-labels-demo — variables
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
  # No default: supply it out-of-band via TF_VAR_state_passphrase (the tftests
  # set their own value). Never commit a real secret.

  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "state_passphrase must be at least 16 characters (PBKDF2 requirement)."
  }
}

# --- Naming / labelling inputs shared by both resources -----------------------

variable "project" {
  description = "Project slug used for naming + the project label."
  type        = string
  default     = "crmapp"
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
  default     = "CC-1234"
}
