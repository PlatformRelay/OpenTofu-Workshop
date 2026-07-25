generate_hcl "_backend.tf" {
  content {
    terraform {
      backend "local" {
        path = global.backend_path
      }
    }
  }
}
