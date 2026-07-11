# =============================================================================
# modules/naming — input variables
# -----------------------------------------------------------------------------
# Composes a deterministic resource name of the form:
#
#     [resource_short]-[project]-[env_short]-[location]-[description]-[suffix]
#
# e.g. aws_s3_bucket in project "crmapp", env "dev", location "euw1", desc
# "web" -> "s3-crmapp-d-euw1-web-a1f3"
#
# Every input is strictly validated so a bad name can never reach a provider.
# =============================================================================

variable "resource_type" {
  description = "OpenTofu resource type to name (e.g. \"aws_s3_bucket\"). Must be a key in var.resource_short_names."
  type        = string

  validation {
    # Lowercase provider_resource form. We do not check membership here (an
    # empty map override would be legal); membership is enforced as an output
    # precondition so the error names the offending type.
    condition     = can(regex("^[a-z][a-z0-9_]+$", var.resource_type))
    error_message = "resource_type must be a lowercase provider resource type such as \"aws_s3_bucket\"."
  }
}

variable "project" {
  description = "Short project / application slug that groups related resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{3,9}$", var.project))
    error_message = "project must be 4-10 chars, lowercase letters/digits, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (e.g. prod, dev, staging). Must be a key in var.environment_short_names."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+$", var.environment))
    error_message = "environment must be lowercase letters only (e.g. \"prod\", \"staging\")."
  }
}

variable "location" {
  description = "Optional short location / region token (e.g. \"euw1\", \"use1\"). Set null to omit."
  type        = string
  default     = null

  validation {
    condition     = var.location == null || can(regex("^[a-z0-9]{2,8}$", var.location))
    error_message = "location must be 2-8 lowercase alphanumerics, or null to omit."
  }
}

variable "description" {
  description = "Optional free-form component describing the resource's role (e.g. \"web\", \"api\"). Set null to omit."
  type        = string
  default     = null

  validation {
    condition     = var.description == null || can(regex("^[a-z0-9]{1,12}$", var.description))
    error_message = "description must be 1-12 lowercase alphanumerics, or null to omit."
  }
}

variable "suffix" {
  description = "Optional explicit suffix. When null a random 4-hex-char suffix is generated for uniqueness."
  type        = string
  default     = null

  validation {
    condition     = var.suffix == null || can(regex("^[a-z0-9]{2,8}$", var.suffix))
    error_message = "suffix must be 2-8 lowercase alphanumerics, or null to auto-generate."
  }
}

# -----------------------------------------------------------------------------
# Swappable profiles
# -----------------------------------------------------------------------------
# The resource_short_names map is a *variable* (not a local) so a consumer can
# drop in an entirely different profile — e.g. the legacy GCP profile — without
# editing the module. The default below is a small AWS profile: extend it as
# your estate grows rather than forking the module.
# -----------------------------------------------------------------------------

variable "resource_short_names" {
  description = "Map of resource_type -> short code. Override to swap cloud profiles (e.g. GCP)."
  type        = map(string)

  default = {
    aws_s3_bucket             = "s3"
    aws_instance              = "ec2"
    aws_vpc                   = "vpc"
    aws_subnet                = "snet"
    aws_iam_role              = "iam"
    aws_iam_policy            = "pol"
    aws_security_group        = "sg"
    aws_db_instance           = "rds"
    aws_lambda_function       = "fn"
    aws_dynamodb_table        = "ddb"
    aws_sqs_queue             = "sqs"
    aws_sns_topic             = "sns"
    aws_ecr_repository        = "ecr"
    aws_kms_key               = "kms"
    aws_cloudwatch_log_group  = "log"
    aws_ecs_service           = "ecs"
    aws_ecs_cluster           = "ecc"
    aws_eks_cluster           = "eks"
    aws_elasticache_cluster   = "ec"
    aws_secretsmanager_secret = "sec"
  }

  validation {
    condition     = length(var.resource_short_names) > 0
    error_message = "resource_short_names must contain at least one entry."
  }

  validation {
    # Every short code must itself be name-safe so the composed name stays clean.
    condition     = alltrue([for code in values(var.resource_short_names) : can(regex("^[a-z0-9]{1,6}$", code))])
    error_message = "every short code must be 1-6 lowercase alphanumerics."
  }
}

variable "environment_short_names" {
  description = "Map of environment -> short code. Override to add environments."
  type        = map(string)

  default = {
    prod    = "p"
    dev     = "d"
    staging = "s"
    test    = "t"
    sandbox = "sb"
    uat     = "u"
    qa      = "q"
    demo    = "dm"
  }

  validation {
    condition     = length(var.environment_short_names) > 0
    error_message = "environment_short_names must contain at least one entry."
  }
}
