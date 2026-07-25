# Optional Terramate root for the capstone stretch.
# Not required by task verify. tofu ignores this file.
terramate {
  required_version = ">= 0.14.0"

  config {
    git {
      default_branch = "main"
    }
  }
}
