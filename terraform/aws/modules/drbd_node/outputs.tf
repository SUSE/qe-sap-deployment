data "aws_instance" "drbd" {
  count       = var.drbd_count
  instance_id = element(aws_instance.drbd.*.id, count.index)
}

output "drbd_ip" {
  value = data.aws_instance.drbd.*.private_ip
}

output "drbd_public_ip" {
  value = data.aws_instance.drbd.*.public_ip
}

output "drbd_name" {
  value = data.aws_instance.drbd.*.id
}

output "drbd_public_name" {
  value = data.aws_instance.drbd.*.public_dns
}

output "subnets_by_az" {
  value = {
    for s in aws_subnet.drbd-subnet :
    s.availability_zone => s.id
  }
}
