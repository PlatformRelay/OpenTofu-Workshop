resource "local_file" "hello" {
  content  = "hello, opentofu\n"
  filename = "${path.module}/hello.txt"
}
