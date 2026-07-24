resource "local_file" "marker" {
  filename = "${path.module}/app.marker"
  content  = "app\n"
}
