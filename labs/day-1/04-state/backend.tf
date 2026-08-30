# Where this project's state lives — kept in its OWN file so the backend can be
# swapped without touching main.tf (the config the S04 slides teach).
#
# Step 5 edits the path below (a learner edit — cleanup reverts it). The
# Stretch parks this whole file as backend.tf.off and activates the S3 variant
# from backend-s3.tf.off instead — same migration, real remote backend.
terraform {
  # State lives on the LOCAL backend by default. This explicit block names the
  # path so we can migrate it later with `tofu init -migrate-state`.
  backend "local" {
    path = "terraform.tfstate"
  }
}
