resource "local_file" "foo" {
  # 10 is the default parallel level in terraform when not using -parallelism=N
  # so use it to maximise the difference in using or not using the argument
  count    = 10
  content  = "@${timestamp()} foo@"
  filename = "${path.module}/foo.${count.index}.bar"
  provisioner "local-exec" {
    command = "sleep 2 ; date +'%T %N'"
  }
}
