variable "cloud_region" {
  description = "OVH S3 region code, e.g. gra, sbg, de, uk, waw, bhs."
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

variable "bucket_suffix" {
  description = "Optional explicit name suffix; null lets modules/naming generate a random one."
  type        = string
  default     = null
}
