terraform {
  required_providers {
    random = { source = "hashicorp/random" }
  }
}

# A generated secret — the kind of value that ends up in state as plaintext.
resource "random_password" "db" {
  length = 20
}
