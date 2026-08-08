# Root Terragrunt configuration — illustrative fixture only (Lab 27).
# The workshop does not install or run Terragrunt; you only READ this tree
# and map its concepts onto the Terramate workdirs from S21-S23.

# PLANTED CLAIM — wrong on purpose (Lab 27 break → fix):
# "remote_state means Terragrunt itself stores this state and serves it
# to the team, like a TACO platform's hosted backend."

remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    path = "terraform.tfstate"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
    provider "local" {}
  EOF
}
