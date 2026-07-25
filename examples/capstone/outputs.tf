# =============================================================================
# examples/capstone — outputs
# =============================================================================

output "artifacts_bucket_name" {
  description = "Composed S3 artifact-store name."
  value       = module.artifacts_name.name
}

output "index_table_name" {
  description = "Composed DynamoDB index-table name."
  value       = module.index_name.name
}

output "work_queue_name" {
  description = "Composed SQS work-queue name."
  value       = module.queue_name.name
}

output "labels" {
  description = "Shared label/tag map applied to every colony resource."
  value       = module.labels.labels
}
