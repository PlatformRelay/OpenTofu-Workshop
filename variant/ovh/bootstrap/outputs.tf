output "s3_access_key_id" {
  description = "S3 access key id for the Object Storage user (export as AWS_ACCESS_KEY_ID)."
  value       = ovh_cloud_project_user_s3_credential.s3.access_key_id
  sensitive   = true
}

output "s3_secret_access_key" {
  description = "S3 secret access key (export as AWS_SECRET_ACCESS_KEY). Shown once; also in state."
  value       = ovh_cloud_project_user_s3_credential.s3.secret_access_key
  sensitive   = true
}

output "project_user_username" {
  description = "OpenStack username of the created Object Storage user."
  value       = ovh_cloud_project_user.s3.username
}

output "alert_id" {
  description = "Id of the created budget alert."
  value       = ovh_cloud_project_alerting.budget.id
}
