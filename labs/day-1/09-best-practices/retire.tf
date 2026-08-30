# Retirement paper trail (Step 12): out/build-info.env used to be
# managed here as local_file.build_info. The resource block is deleted;
# this removed block hands the file over — OpenTofu FORGETS the object
# without destroying it. Like moved, an applied removed block is inert
# history and safe to keep.
removed {
  from = local_file.build_info

  # Say the intent out loud. destroy = false means "forget, don't
  # destroy". Omitting the lifecycle block still forgets — but with a
  # warning — and destroy = true flips this same block into a real
  # destroy of the artifact.
  lifecycle {
    destroy = false
  }
}
