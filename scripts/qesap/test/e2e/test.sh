#!/bin/bash -e

test_step () {
  echo "#######################################################################"
  echo "# $1"
  echo "#######################################################################"
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
test_step "First minimal run of qesap.py"
qesap.py --version || test_die "qesap.py not in PATH"


echo "#######################################################################"
echo "###                                                                 ###"
echo "###                      C O N F I G U R E                          ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Configure has to fail with empty yaml"
set +e
qesap.py --verbose -b ${QESAPROOT} -c test_1.yaml configure
rc=$?; [[ $rc -ne 0 ]] || test_die "Should exit with zero rc but is rc:$rc"
set -e

test_step "Minimal configure only with Terraform"
# `qesap.py configure` generate a terraform.tfvars file
# in the provider folder indicated in the conf.yaml
# and with content from the conf.yaml terraform section
TEST_PROVIDER="${QESAPROOT}/terraform/fragola"
mkdir -p "${TEST_PROVIDER}"
qesap.py --verbose -b ${QESAPROOT} -c test_2.yaml configure || test_die "Should exit with zero rc but is rc:$?"
TEST_TERRAFORM_TFVARS="${TEST_PROVIDER}/terraform.tfvars"
test_file "${TEST_TERRAFORM_TFVARS}"
grep -q lampone "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml should contain the world lampone"

test_step "[test_3.yaml] configure with also Ansible"
# `qesap.py configure` generate some ansible .yaml files
TEST_ANSIBLE_VARS="${QESAPROOT}/ansible/playbooks/vars"
mkdir -p "${TEST_ANSIBLE_VARS}"
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml configure || test_die "Should exit with zero rc but is rc:$?"
TEST_ANSIBLE_MEDIA="${TEST_ANSIBLE_VARS}/hana_media.yaml"
test_file "${TEST_ANSIBLE_MEDIA}"
grep -q corniolo "${TEST_ANSIBLE_MEDIA}" || test_die "${TEST_ANSIBLE_MEDIA} generated from test_3.yaml should contain the corniolo"

test_step "[test_5.yaml] Change a setting in place"
# This test try to reproduce the situation in which
# a user run `qesap.py conf.yaml` a first time
# then tune and change something in the config.yaml
# and run the `qesap.py conf.yaml` a second time
# to have the changes applied in the generated .tfvars or ansible files
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml configure || test_die "Should exit with zero rc but is rc:$?"
grep -q lampone "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_3.yaml should contain the world lampone"

# test_5 has everything the same as test_3 except for a terraform variable,
# verify that running the configure command in place result in the .tfvars file to change
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml configure || test_die "Should exit with zero rc but is rc:$?"
test_file "${TEST_TERRAFORM_TFVARS}"
set +e
grep -q lampone "${TEST_TERRAFORM_TFVARS}"
rc=$?; [[ $rc -ne 0 ]] || test_die "${TEST_TERRAFORM_TFVARS} generated from test_5.yaml should no more contain the world lampone"
set -e
grep -q jam "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_5.yaml should contain the world jam"

test_step "[test_1.yaml] test stdout for configure FAIL"
# can run without verbosity and if ok print anything
rm "${QESAPROOT}/test_1_configure.txt" || echo "No ${QESAPROOT}/test_1_configure.txt to delete"
set +e
qesap.py -b ${QESAPROOT} -c test_1.yaml configure |& tee "${QESAPROOT}/test_1_configure.txt"

grep -qE "^DEBUG" "${QESAPROOT}/test_1_configure.txt"
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc in verbose mode there should be any DEBUG"

grep -qE "^INFO" "${QESAPROOT}/test_1_configure.txt"
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc in verbose mode there should be any INFO"

grep -qE "^ERROR" "${QESAPROOT}/test_1_configure.txt"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some ERROR"
set -e
rm "${QESAPROOT}/test_1_configure.txt"

test_step "[test_1.yaml] test stdout with verbose for configure FAIL"
rm "${QESAPROOT}/test_1_configure_verbose.txt" || echo "No ${QESAPROOT}/test_1_configure_verbose.txt to delete"
set +e
qesap.py --verbose -b ${QESAPROOT} -c test_1.yaml configure |& tee "${QESAPROOT}/test_1_configure_verbose.txt"

grep -qE "^DEBUG" "${QESAPROOT}/test_1_configure_verbose.txt"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${QESAPROOT}/test_1_configure_verbose.txt"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

grep -qE "^ERROR" "${QESAPROOT}/test_1_configure_verbose.txt"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some ERROR"
set -e
rm "${QESAPROOT}/test_1_configure_verbose.txt"

test_step "[test_5.yaml] test stdout for configure PASS"
rm "${QESAPROOT}/test_5_configure.txt" || echo "No ${QESAPROOT}/test_5_configure.txt to delete"
# can run without verbosity and if ok print anything
qesap.py -b ${QESAPROOT} -c test_5.yaml configure |& tee "${QESAPROOT}/test_5_configure.txt"

lines=$(cat "${QESAPROOT}/test_5_configure.txt" | wc -l)
[[ $lines -eq 0 ]] || test_die "${QESAPROOT}/test_5_configure.txt should be empty but has $lines lines"

rm "${QESAPROOT}/test_5_configure.txt"


test_step "[test_5.yaml] test stdout with verbosity for configure PASS"
rm "${QESAPROOT}/test_5_configure_verbose.txt" || echo "No ${QESAPROOT}/test_5_configure_verbose.txt to delete"
# run the same with verbosity
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml configure |& tee "${QESAPROOT}/test_5_configure_verbose.txt"

grep -qE "^DEBUG" "${QESAPROOT}/test_5_configure_verbose.txt"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${QESAPROOT}/test_5_configure_verbose.txt"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

rm "${QESAPROOT}/test_5_configure_verbose.txt"

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                      T E R R A F O R M                          ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "[test_3.yaml] Terraform FAILURE for invalid code in main.tf"
# Create an invalid main.tf.
# The non zero exit code from terraform has to be correctly propagated
# through the qesap.py
echo "SOMETHING INVALID" > "${TEST_PROVIDER}/main.tf"
set +e
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml terraform
rc=$?; [[ $rc -ne 0 ]] || test_die "Should exit with non zero rc but is rc:$rc"
set -e
rm "${TEST_PROVIDER}/main.tf"

test_step "[test_3.yaml] Run Terraform"
# correct execution of terraform: test is checking for 0 exit code
# and for the generation of the terraform.tfstate
# terraform.tfstate is directly created by the terraform executable
# Test is using an empty main.tf placed in the right provider folder
touch "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml terraform || test_die "test_3.yaml fail on terraform"
TEST_TERRAFORM_TFSTATE="${TEST_PROVIDER}/terraform.tfstate"
test_file "${TEST_TERRAFORM_TFSTATE}"

test_step "[test_5.yaml] test stdout for terraform PASS"
# run `qesap.py terraform` both with and without `--verbose`
# - The stdout in --verbose has to have some strings starting with both DEBUG and INFO
# - in case of pass and without --verbose, `qesap.py terraform` has not to emit any line

# run in non verbose mode
THIS_LOG="${QESAPROOT}/test_5_terraform.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
qesap.py -b ${QESAPROOT} -c test_5.yaml terraform |& tee "${THIS_LOG}"

lines=$(cat "${THIS_LOG}" | wc -l)
[[ $lines -eq 0 ]] || test_die "${THIS_LOG} should be empty but has $lines lines"
rm "${THIS_LOG}"

test_step "[test_5.yaml] test stdout with verbosity for terraform PASS"
THIS_LOG="${QESAPROOT}/test_5_terraform_verbose.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
# now repeat exactly the same in --verbose mode
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml terraform |& tee "${THIS_LOG}"

set +e
grep -qE "^DEBUG" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

# check for duplicated lines
lines=$(grep -c "Apply complete!" "${THIS_LOG}")
[[ $lines -eq 1 ]] || test_die "${THIS_LOG} there's one message in the log repeated $lines times."
set -e
rm "${THIS_LOG}"

test_step "[test_5.yaml] test .log.txt file redirection"
# run `qesap.py terraform` both with and without `--verbose`
# - `qesap.py terraform` redirect all the terraform stdout and stderr for each of the
#    executed terraform command (init, plan and apply) to a dedicated log file

# run in non verbose mode
rm terraform.*.log.txt || echo "No terraform.*.log.txt to delete"
qesap.py -b ${QESAPROOT} -c test_5.yaml terraform

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
rm terraform.*.log.txt

# now repeat exactly the same in --verbose mode
qesap.py --verbose -b ${QESAPROOT} -c test_5.yaml terraform

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
rm terraform.*.log.txt

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                         A N S I B L E                           ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "[test_4.yaml] Run Ansible without inventory"
# Ansible without inventory is expected to fails
rm "${TEST_PROVIDER}/inventory.yaml" || echo "No old inventory to remove"
set +e
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml ansible
rc=$?; [[ $rc -ne 0 ]] || test_die "qesap.py ansible has to fail without inventory.yaml but rc:$rc"
set -e

test_step "[test_3.yaml] Run Ansible with no playbooks"
# Keep in mind that test_3.yaml has no playbooks at all
touch "${TEST_PROVIDER}/inventory.yaml"
qesap.py --verbose -b ${QESAPROOT} -c test_3.yaml ansible || test_die "test_3.yaml fail on ansible"

test_step "[test_3.yaml] Run Ansible with NO playbooks"
qesap.py -b ${QESAPROOT} -c test_3.yaml ansible || test_die "test_3.yaml fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
[[ $ansible_logs_number -eq 0 ]] || test_die "ansible .log.txt are not 0 files but has ${ansible_logs_number}"

test_step "[test_4.yaml] Run Ansible dryrun"
THIS_LOG="${QESAPROOT}/ansible.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
cp inventory.yaml "${TEST_PROVIDER}/inventory.yaml"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml configure || test_die "test_4.yaml fail on configure"
# At the moment e2e does not ahve a way to really run ansible
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml --dryrun ansible || test_die "test_4.yaml fail on ansible"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml --dryrun ansible |& tee "${THIS_LOG}"
grep -E "ansible.*-i.*fragola/inventory.yaml.*all.*ssh-extra-args" \
    "${THIS_LOG}" || test_die "test_4.yaml dryrun fails in ansible command"
grep -E "ansible-playbook.*-i.*fragola/inventory.yaml.*ansible/playbooks/sambuconero.yaml" \
    "${THIS_LOG}" || test_die "test_4.yaml dryrun fails in ansible-playbook command"
rm "${THIS_LOG}"

test_step "[test_4.yaml] Run Ansible PASS"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml ansible || test_die "test_4.yaml fail on ansible"

test_step "[test_4.yaml] Ansible stdout in case of PASS"
THIS_LOG="${QESAPROOT}/test_4_ansible_pass.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
qesap.py -b ${QESAPROOT} -c test_4.yaml ansible |& tee "${THIS_LOG}"
lines=$(cat "${THIS_LOG}" | wc -l)
[[ $lines -eq 0 ]] || test_die "${THIS_LOG} should be empty but has $lines lines"
rm "${THIS_LOG}"

test_step "[test_4.yaml] Ansible stdout with verbosity in case of PASS"
THIS_LOG="${QESAPROOT}/test_4_ansible_pass_verbose.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG}"
qesap.py --verbose -b ${QESAPROOT} -c test_4.yaml ansible |& tee "${THIS_LOG}"
set +e
grep -qE "^DEBUG" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

occurrence=$(grep -cE "TASK \[Say hello\]" "${THIS_LOG}")
[[ $occurrence -eq 1 ]] || test_die "Some Ansible stdout lines are repeated ${occurrence} times in place of exactly 1"
set -e
rm "${THIS_LOG}"

test_step "[test_6.yaml] Check redirection to file of Ansible logs"
rm ansible.*.log.txt || echo "Nothing to delete"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/timbio.yaml"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/buga.yaml"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/purace.yaml"
qesap.py -b ${QESAPROOT} -c test_6.yaml ansible || test_die "test_6.yaml fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
# 3 playbooks plus a log file for the initial ansible (not ansible-playbook) call 
[[ $ansible_logs_number -eq 4 ]] || test_die "ansible .log.txt are not 4 files but has ${ansible_logs_number}"
rm ansible.*.log.txt
