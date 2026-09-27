variable "enable_random_pet" {
  description = "Create the optional stretch resource."
  type        = bool
  default     = false
}

resource "random_pet" "stretch" {
  count  = var.enable_random_pet ? 1 : 0
  length = 2
}
