variable "name" {
  type        = string
  description = "Who to greet."
}

output "message" {
  description = "The rendered greeting line."
  value       = "Hello, ${var.name}!"
}
