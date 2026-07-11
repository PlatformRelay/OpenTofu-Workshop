# =============================================================================
# examples/naming-labels-demo — outputs
# =============================================================================

output "bucket_name" {
  description = "Composed S3 bucket name."
  value       = module.bucket_name.name
}

output "table_name" {
  description = "Composed DynamoDB table name."
  value       = module.table_name.name
}

output "labels" {
  description = "The shared label/tag map applied to both resources."
  value       = module.labels.labels
}
