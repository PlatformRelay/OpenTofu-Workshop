# Reference it, don't own it: a data source READS the bucket at plan time.
# It never enters this config's managed state, so destroy cannot touch it.
data "aws_s3_bucket" "legacy" {
  bucket = "workshop-legacy-reports"
}

output "legacy_bucket_arn" {
  description = "ARN of the bucket another config owns, looked up read-only."
  value       = data.aws_s3_bucket.legacy.arn
}
