# The module's OUTPUT contract. A caller reads these; the resources stay private.
output "manifest_path" {
  description = "Where this instance's rendered manifest landed."
  value       = local_file.manifest.filename
}

output "release" {
  description = "The generated release name for this instance."
  value       = random_pet.release.id
}
