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
set +e
qesap.py --verbose -b ${QESAPROOT} -c test_1.yaml configure; rc=$?; if [ $rc -eq 0 ]; then test_die "rc:$rc Should exit with non zero rc but was not"; fi
set -e

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

test_step "[test_3.yaml] Terraform FAILURE"
echo "SOMETHING INVALID" > "${TEST_PROVIDER}/main.tf"
set +e
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml terraform; rc=$?; if [ $rc -eq 0 ]; then test_die "rc:$rc Should exit with non zero rc but was not"; fi
set -e
rm "${TEST_PROVIDER}/main.tf"

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
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml --dryrun ansible |& tee "${QESAPROOT}/ansible.log"
grep -E "ansible.*-i.*fragola/inventory.yaml.*all.*ssh-extra-args" "${QESAPROOT}/ansible.log" || test_die "test_4.yaml dryrun fails in ansible command"
grep -E "ansible-playbook.*-i.*fragola/inventory.yaml.*ansible/playbooks/sambuconero.yaml" "${QESAPROOT}/ansible.log" || test_die "test_4.yaml dryrun fails in ansible-playbook command"

test_step "[test_5.yaml] Change a setting in place"
# test_5 has everything the same of test_4 except a terraform variable,
# verify that running the configure command in place result in the .tfvars file to change
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml configure || test_die "Should exit with zero rc but was not. rc:$?"
test_file "${TEST_TERRAFORM_TFVARS}"
grep -q lampone "${TEST_TERRAFORM_TFVARS}" && test_die "${TEST_TERRAFORM_TFVARS} generated from test_5.yaml should no more contain the world lampone"
grep -q jam "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_5.yaml should contain the world jam"

test_step "[test_1.yaml] test verbosity for configure FAIL"
# can run without verbosity and if ok print anything
set +e
qesap.py -b ${QESAPROOT} -c test_1.yaml configure |& tee "${QESAPROOT}/test_1_configure.txt"
qesap.py --verbose -b ${QESAPROOT} -c test_1.yaml configure |& tee "${QESAPROOT}/test_1_configure_verbose.txt"
grep -qE "^DEBUG" "${QESAPROOT}/test_1_configure_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some DEBUG"; fi
grep -qE "^INFO" "${QESAPROOT}/test_1_configure_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some INFO"; fi
grep -qE "^ERROR" "${QESAPROOT}/test_1_configure_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some ERROR"; fi

grep -qE "^DEBUG" "${QESAPROOT}/test_1_configure.txt"; rc=$?; if [ $rc -eq 0 ]; then test_die "rc:$rc in verbose mode there should be any DEBUG"; fi
grep -qE "^INFO" "${QESAPROOT}/test_1_configure.txt"; rc=$?; if [ $rc -eq 0 ]; then test_die "rc:$rc in verbose mode there should be any INFO"; fi
grep -qE "^ERROR" "${QESAPROOT}/test_1_configure.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some ERROR"; fi
set -e
rm "${QESAPROOT}/test_1_configure.txt"
rm "${QESAPROOT}/test_1_configure_verbose.txt"

test_step "[test_5.yaml] test verbosity for configure PASS"
# can run without verbosity and if ok print anything
qesap.py -b ${QESAPROOT} -c test_5.yaml configure |& tee "${QESAPROOT}/test_5_configure.txt"
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml configure |& tee "${QESAPROOT}/test_5_configure_verbose.txt"
grep -qE "^DEBUG" "${QESAPROOT}/test_5_configure_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some DEBUG"; fi
grep -qE "^INFO" "${QESAPROOT}/test_5_configure_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some INFO"; fi
lines=$(cat "${QESAPROOT}/test_5_configure.txt" | wc -l)
if [ $lines -ne 0 ]; then test_die "${QESAPROOT}/test_5_configure.txt should be empty but has $lines lines"; fi
rm "${QESAPROOT}/test_5_configure.txt"
rm "${QESAPROOT}/test_5_configure_verbose.txt"

test_step "[test_5.yaml] test verbosity for terraform PASS"
rm terraform.*.log.txt
qesap.py -b ${QESAPROOT} -c test_5.yaml terraform |& tee "${QESAPROOT}/test_5_terraform.txt"
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml configure |& tee "${QESAPROOT}/test_5_terraform_verbose.txt"
grep -qE "^DEBUG" "${QESAPROOT}/test_5_terraform_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some DEBUG"; fi
grep -qE "^INFO" "${QESAPROOT}/test_5_terraform_verbose.txt"; rc=$?; if [ $rc -ne 0 ]; then test_die "rc:$rc in verbose mode there should be some INFO"; fi
lines=$(cat "${QESAPROOT}/test_5_terraform.txt" | wc -l)
if [ $lines -ne 0 ]; then test_die "${QESAPROOT}/test_5_terraform.txt should be empty but has $lines lines"; fi
find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
