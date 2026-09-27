output "bucket_name" {
  description = "Composed S3 bucket name."
  value       = module.bucket_name.name
}

output "labels" {
  description = "The shared label/tag map applied to the bucket."
  value       = module.labels.labels
}
