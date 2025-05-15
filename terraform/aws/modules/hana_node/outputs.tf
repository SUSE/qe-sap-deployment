data "aws_instance" "hana" {
  count       = var.hana_count
  instance_id = element(aws_instance.hana.*.id, count.index)
}

output "hana_ip" {
  value = data.aws_instance.hana.*.private_ip
}

output "hana_public_ip" {
  value = data.aws_instance.hana.*.public_ip
}

output "hana_name" {
  value = data.aws_instance.hana.*.id
}

output "hana_public_name" {
  value = data.aws_instance.hana.*.public_dns
}

output "stonith_tag" {
  value = local.hana_stonith_tag
}

output "subnets_by_az" {
  value = {
    for s in aws_subnet.hana-subnet :
    s.availability_zone => s.id
  }
}

output "volume_id_to_device_name" {
  value = [
    for inst in aws_instance.hana :
    { for bd in inst.ebs_block_device :
      bd.volume_id => bd.device_name
    }
  ]
  description = "EBS volume‑ID -> /dev/sdX"
}
