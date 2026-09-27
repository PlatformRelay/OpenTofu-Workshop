output "artifacts_bucket_name" {
  description = "Composed artifacts bucket name."
  value       = module.artifacts_name.name
}

output "archive_bucket_name" {
  description = "Composed archive bucket name."
  value       = module.archive_name.name
}

output "labels" {
  description = "Shared label/tag map applied to every colony resource."
  value       = module.labels.labels
}
