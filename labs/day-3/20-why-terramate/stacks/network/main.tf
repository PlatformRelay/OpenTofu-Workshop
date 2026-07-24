resource "local_file" "marker" {
  filename = "${path.module}/network.marker"
  content  = "network\n"
}
