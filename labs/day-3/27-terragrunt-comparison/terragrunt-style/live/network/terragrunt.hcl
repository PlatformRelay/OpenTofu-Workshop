# Network unit — illustrative fixture only (Lab 27). Never executed.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../units/network"
}
