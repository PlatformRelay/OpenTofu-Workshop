# The config the adopted bucket must MATCH. Importing binds this block to the
# real object; it does NOT rewrite reality to fit your code. Any attribute that
# disagrees with the live object shows up in the importing plan as a change.
variable "adopted_bucket_name" {
  description = "Name of the bucket you created in the OVH Manager to adopt. You MUST set TF_VAR_adopted_bucket_name to YOUR unique bucket name; there is no default because OVH names are globally unique."
  type        = string
  # No default: this root is applied by hand during the import exercise, and
  # OVH names are globally unique, so an unset value must fail loudly rather
  # than target a shared placeholder bucket.
}

resource "aws_s3_bucket" "adopted" {
  bucket = var.adopted_bucket_name

  tags = {
    # Matches the tag the exercise puts on the real bucket. Delete this
    # attribute and the importing plan gains an in-place change.
    owner = "ops"
  }
}

output "adopted_bucket" {
  description = "Name of the bucket adopted into state by the import block."
  value       = aws_s3_bucket.adopted.bucket
}
