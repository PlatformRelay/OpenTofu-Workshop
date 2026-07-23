# =============================================================================
# labs/day-1/10-differentiators — regional resources over the provider fan-out
# =============================================================================
#
# Two resources, each fanned out over the SAME `local.regions` set:
#
#   aws_s3_bucket.regional["<region>"]  — one bucket per region, created by that
#                                         region's provider instance.
#   aws_s3_object.marker["<region>"]    — a leaf that DEPENDS ON its region's
#                                         bucket. This dependency is what the
#                                         `-exclude` break -> fix hinges on.

# One regional bucket per region, each created THROUGH that region's provider
# instance: `provider = aws.by_region[each.key]` selects the matching instance.
resource "aws_s3_bucket" "regional" {
  for_each = local.regions
  provider = aws.by_region[each.key]

  # Bucket names are globally unique, so embed the region.
  bucket = "workshop-${each.key}-data"
}

# A leaf object per region that DEPENDS ON its region's bucket (via the
# `bucket` reference). Excluding a bucket while keeping its object is the
# broken `-exclude` the lab demonstrates.
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
