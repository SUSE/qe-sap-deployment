resource "local_file" "foo" {
  content  = "foo!"
  filename = "${path.module}/foo.bar"
}

output "foo_filename" {
  value = local_file.foo.filename
}

output "foo_list" {
  value = tolist(["a", "b"])
}
