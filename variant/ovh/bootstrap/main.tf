# =============================================================================
# variant/ovh/bootstrap — the OVH-native lab.
# -----------------------------------------------------------------------------
# What LocalStack bootstraps for free (a working S3 endpoint and throwaway
# credentials), OVH requires you to create: an Object Storage user, its S3
# credential pair, and a budget alert. This root does all three with the `ovh`
# provider, and teaches IAM-scoped service-account auth in the process.
#
# The `ovh` provider lives ONLY in this root (layer separation): the twins stay
# on the S3-compatible `aws` provider, so a learner who never touches OVH's API
# never downloads the ovh provider.
# =============================================================================

# An Object Storage user is an OpenStack user carrying the objectstore_operator
# role. The S3 API authenticates as this user.
resource "ovh_cloud_project_user" "s3" {
  service_name = var.ovh_service_name
  description  = var.s3_user_description
  role_names   = ["objectstore_operator"]
}

# The S3 credential pair for that user. The secret is exported sensitive and is
# shown only here — it is also written to this root's state, which is why the
# bootstrap README points at Day-1 S05 state encryption.
resource "ovh_cloud_project_user_s3_credential" "s3" {
  service_name = ovh_cloud_project_user.s3.service_name
  user_id      = ovh_cloud_project_user.s3.id
}

# The declarative budget backstop: an email alert when forecast monthly usage
# crosses the threshold. Created before the learner's first bucket when this
# root runs first; the Manager path covers the fast path.
resource "ovh_cloud_project_alerting" "budget" {
  service_name      = var.ovh_service_name
  email             = var.alert_email
  monthly_threshold = var.alert_monthly_threshold
  delay             = var.alert_delay
}
