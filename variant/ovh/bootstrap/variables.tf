variable "ovh_endpoint" {
  description = "OVH API endpoint: ovh-eu, ovh-ca or ovh-us. Null falls back to OVH_ENDPOINT."
  type        = string
  default     = null

  validation {
    condition     = var.ovh_endpoint == null || contains(["ovh-eu", "ovh-ca", "ovh-us"], var.ovh_endpoint)
    error_message = "ovh_endpoint must be one of: ovh-eu, ovh-ca, ovh-us."
  }
}

variable "ovh_client_id" {
  description = "IAM service account OAuth2 client id. Set via OVH_CLIENT_ID."
  type        = string
  default     = null
  sensitive   = true
}

variable "ovh_client_secret" {
  description = "IAM service account OAuth2 client secret. Set via OVH_CLIENT_SECRET."
  type        = string
  default     = null
  sensitive   = true
}

variable "ovh_service_name" {
  description = "Public Cloud project id. Falls back to OVH_CLOUD_PROJECT_SERVICE when null."
  type        = string
  default     = null
}

variable "s3_user_description" {
  description = "Description recorded on the Object Storage user."
  type        = string
  default     = "opentofu-workshop OVH variant S3 user"
}

variable "alert_email" {
  description = "Email that receives the budget alert. Set via TF_VAR_alert_email to an address you read."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "alert_email must look like an email address."
  }
}

variable "alert_monthly_threshold" {
  description = "Monthly consumption threshold, in the project's currency."
  type        = number
  default     = 10

  validation {
    condition     = var.alert_monthly_threshold > 0
    error_message = "alert_monthly_threshold must be greater than zero."
  }
}

variable "alert_delay" {
  description = "Minimum seconds between two budget alerts."
  type        = number
  default     = 3600

  validation {
    condition     = var.alert_delay >= 0
    error_message = "alert_delay must be zero or more seconds."
  }
}
