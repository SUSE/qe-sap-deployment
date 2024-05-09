#!/bin/bash -e

test_step () {
  echo "##############################"
  echo "# $1"
  echo "##############################"
}

test_die () {
  echo "DIE($?) : $1"
  exit 1
}

test_file () {
  [[ -f "$1" ]] || test_die "Generated file $1 not found!"
}

test_step "Initial folder structure cleanup and preparation"
QESAPROOT="$(dirname $0)/test_repo"
rm -rf "${QESAPROOT}"
mkdir ${QESAPROOT}

PATH="$(dirname $0)/../..":$PATH
qesap.py --version || test_die "qesap.py not in PATH"

test_step "Configure has to fail with empty yaml"
qesap.py --verbose -b ${QESAPROOT} -c test_1.yaml configure && test_die "Should exit with non zero rc but was not"

test_step "Minimal configure only with Terraform"
TEST_PROVIDER="${QESAPROOT}/terraform/fragola"
mkdir -p "${TEST_PROVIDER}"
qesap.py --verbose -b ${QESAPROOT} -c test_2.yaml configure || test_die "Should exit with zero rc but was not. rc:$?"
TEST_TERRAFORM_TFVARS="${TEST_PROVIDER}/terraform.tfvars"
test_file "${TEST_TERRAFORM_TFVARS}"
grep -q lampone "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml should contain the world lampone"

test_step "[test_3.yaml] Minimal configure only with Terraform"
TEST_ANSIBLE_VARS="${QESAPROOT}/ansible/playbooks/vars"
mkdir -p "${TEST_ANSIBLE_VARS}"
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml configure || test_die "Should exit with zero rc but was not. rc:$?"
TEST_ANSIBLE_MEDIA="${TEST_ANSIBLE_VARS}/hana_media.yaml"
test_file "${TEST_ANSIBLE_MEDIA}"
grep -q corniolo "${TEST_ANSIBLE_MEDIA}" || test_die "${TEST_ANSIBLE_MEDIA} generated from test_3.yaml should contain the corniolo"

test_step "[test_3.yaml] Run Terraform"
touch "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml terraform || test_die "test_3.yaml fail on terraform"
TEST_TERRAFORM_TFSTATE="${TEST_PROVIDER}/terraform.tfstate"
test_file "${TEST_TERRAFORM_TFSTATE}"

test_step "[test_3.yaml] Run Ansible"
# Keep in mind that test_3.yaml has no playbooks at all
touch "${TEST_PROVIDER}/inventory.yaml"
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml ansible || test_die "test_3.yaml fail on ansible"

test_step "[test_4.yaml] Run Ansible create"
touch "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
cp inventory.yaml "${TEST_PROVIDER}/inventory.yaml"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml configure || test_die "test_4.yaml fail on configure"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml --dryrun ansible || test_die "test_4.yaml fail on ansible"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml --dryrun ansible | tee "${QESAPROOT}/ansible.log"
grep -E "ansible.*-i.*fragola/inventory.yaml.*all.*ssh-extra-args" "${QESAPROOT}/ansible.log" || test_die "test_4.yaml dryrun fails in ansible command"
grep -E "ansible-playbook.*-i.*fragola/inventory.yaml.*ansible/playbooks/sambuconero.yaml" "${QESAPROOT}/ansible.log" || test_die "test_4.yaml drayrun fails in ansible-playbook command"
