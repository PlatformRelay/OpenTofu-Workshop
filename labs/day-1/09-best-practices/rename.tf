# Companion artifact: release notes rendered beside the manifests.
# This resource was BORN as local_file.notes; the Step 11 refactor
# renamed the ADDRESS. Nothing about the real file changed — which is
# exactly why the rename must be a state edit, not a rebuild.
resource "local_file" "release_notes" {
  filename = "${path.module}/out/RELEASE.md"
  content  = "# Release: checkout, payments, search\n"
}

# moved: a plain RENAME — the smallest state surgery there is. Without
# this block the rename plans 1 to add, 1 to destroy (a new address is
# a new resource); with it, "has moved to" and a 0/0/0 no-op. Applied
# moved blocks are inert history: keep them as the paper trail.
moved {
  from = local_file.notes
  to   = local_file.release_notes
}
