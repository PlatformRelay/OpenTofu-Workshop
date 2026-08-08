# App unit — illustrative fixture only (Lab 27). Never executed.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../units/app"
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    network_name = "mock-network"
  }
}

inputs = {
  network_name = dependency.network.outputs.network_name
}
