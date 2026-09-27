# =============================================================================
# OVH twin of Lab 10 — regional resources over the provider fan-out.
# -----------------------------------------------------------------------------
# One bucket and one marker object per region, each created THROUGH that
# region's provider instance. The names are composed by modules/naming (random
# suffix) because OVH bucket names are globally unique.
# =============================================================================

variable "bucket_suffix" {
  description = "Optional explicit suffix per region; null lets modules/naming generate a random one."
  type        = string
  default     = null
}

module "bucket_name" {
  source   = "../../../../../modules/naming"
  for_each = local.regions

  resource_type = "aws_s3_bucket"
  project       = "workshop"
  environment   = "dev"
  location      = each.key
  description   = "data"
  suffix        = var.bucket_suffix
}

resource "aws_s3_bucket" "regional" {
  for_each = local.regions
  provider = aws.by_region[each.key]

  bucket = module.bucket_name[each.key].name
}

# A leaf object per region that DEPENDS ON its region's bucket. Excluding a
# bucket while keeping its object is the broken `-exclude` the lab demonstrates.
resource "aws_s3_object" "marker" {
  for_each = local.regions
  provider = aws.by_region[each.key]

  bucket  = aws_s3_bucket.regional[each.key].id
  key     = "region.txt"
  content = "region=${each.key}\n"
}

output "bucket_names" {
  description = "The regional bucket name created per region."
  value       = { for k, b in aws_s3_bucket.regional : k => b.bucket }
}
