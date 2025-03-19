#!/bin/bash

img_name=$1
cre="${cre:-"podman"}"

#$cre build -f Dockerfile -t "${img_name}"

echo "=== Test terraform binary"
$cre run "${img_name}" terraform --version | grep 1.5.7 || ( echo "ERROR[$?] wrong or not usable Terraform" ; exit 1 )
$cre run -v $(pwd):/src "${img_name}" terraform -chdir=/src/terraform/azure init || ( echo "ERROR[$?] terraform init does not work for azure" ; exit 1 )
$cre run -v $(pwd):/src "${img_name}" terraform -chdir=/src/terraform/aws init || ( echo "ERROR[$?] terraform init does not work for aws" ; exit 1 )
$cre run  -v $(pwd):/src "${img_name}" terraform -chdir=/src/terraform/gcp init || ( echo "ERROR[$?] terraform init does not work for google" ; exit 1 )

echo "=== Test ansible"
$cre run "${img_name}" python3.11 --version | grep 3.11 || ( echo "ERROR[$?] wrong or not usable Python" ; exit 1 )
$cre run "${img_name}" pip3.11 --version || ( echo "ERROR[$?] wrong or not usable pip" ; exit 1 )
$cre run "${img_name}" pip3.11 freeze | grep ansible-core || ( echo "ERROR[$?] ansible-core not installed" ; exit 1 )
$cre run "${img_name}" ansible --version || ( echo "ERROR[$?] wrong or not usable Terraform" ; exit 1 )
$cre run "${img_name}" ansible-galaxy --version || ( echo "ERROR[$?] wrong or not usable Terraform" ; exit 1 )

echo "=== Test awscli"
$cre run "${img_name}" pip3.11 freeze | grep aws || ( echo "ERROR[$?] aws cli not installed" ; exit 1 )
$cre run "${img_name}" aws --version || ( echo "ERROR[$?] wrong or not usable aws" ; exit 1 )

echo "=== Test az"
$cre run "${img_name}" az --version || ( echo "ERROR[$?] wrong or not usable az" ; exit 1 )

echo "=== Test gcloud"
$cre run "${img_name}" cat /root/.bashrc
$cre run "${img_name}" /root/google-cloud-sdk/bin/gcloud --version

