terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

variable "enable_random_pet" {
  description = "Create the optional stretch resource."
  type        = bool
  default     = false
}

resource "local_file" "hello" {
  content  = "hello, opentofu\n"
  filename = "${path.module}/hello.txt"
}

resource "random_pet" "stretch" {
  count  = var.enable_random_pet ? 1 : 0
  length = 2
}
