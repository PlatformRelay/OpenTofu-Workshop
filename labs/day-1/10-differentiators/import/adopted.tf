# The config the adopted bucket must MATCH. Importing binds this block
# to the real object; it does NOT rewrite reality to fit your code.
# Any attribute that disagrees with the live object shows up in the
# importing plan as a change — the lab makes you read exactly that.
resource "aws_s3_bucket" "adopted" {
  bucket = "workshop-adopted-logs"

  tags = {
    # Matches the tag Step 5 puts on the real bucket. Delete this
    # attribute and the importing plan gains an in-place change.
    owner = "ops"
  }
}

output "adopted_bucket" {
  description = "Name of the bucket adopted into state by the import block."
  value       = aws_s3_bucket.adopted.bucket
}
