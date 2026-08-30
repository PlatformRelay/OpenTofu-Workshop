# Declarative adoption: an `import` block is PLANNED like any other
# change — reviewable in a diff, dry-runnable, and removable once the
# object is in state (it becomes a no-op after the importing apply).
#
# `to` is the config address that will own the object; `id` is the
# provider-native identifier of the REAL object (for S3: the bucket
# name). Lab 10's Step 5 creates that bucket out-of-band with
# awslocal — the "existing infrastructure" this part adopts.
import {
  to = aws_s3_bucket.adopted
  id = "workshop-adopted-logs"
}
