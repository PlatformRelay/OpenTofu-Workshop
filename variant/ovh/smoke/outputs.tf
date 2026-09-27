output "bucket_name" {
  description = "The composed bucket name the smoke run created."
  value       = aws_s3_bucket.smoke.bucket
}

output "endpoint" {
  description = "The OVH S3 endpoint the run used."
  value       = "https://s3.${var.cloud_region}.io.cloud.ovh.net"
}
