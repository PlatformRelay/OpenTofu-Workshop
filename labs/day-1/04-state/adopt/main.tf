# The resource block you write FIRST: it describes the bucket someone created
# in the console. On its own it means "create this" — the import block
# (import.tf, activated in Step 8c) turns it into "adopt this".
resource "aws_s3_bucket" "legacy" {
  bucket = "workshop-legacy-reports"
}

output "legacy_bucket_arn" {
  description = "ARN of the adopted bucket, read from state after the import."
  value       = aws_s3_bucket.legacy.arn
}
