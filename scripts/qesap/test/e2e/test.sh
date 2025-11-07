#!/bin/bash -e
TROOT=$(dirname $0)
QESAPROOT="${TROOT}/test_repo"
PROVIDER="fragola"
TEST_PROVIDER="${QESAPROOT}/terraform/${PROVIDER}"
TEST_ANSIBLE_VARS="${QESAPROOT}/ansible/playbooks/vars"
PATH="${TROOT}/../..":$PATH

reset_root () {
  echo "Clean and create folder structure for QESAPROOT in ${TROOT}"
  rm -rf "${TROOT}/test_repo"
  echo "TEST_PROVIDER:__${TEST_PROVIDER}__"
  mkdir -p "${TEST_PROVIDER}"
  mkdir -p "${TEST_ANSIBLE_VARS}"
}

test_split () {
   echo "---------------------------------------------------------------------"
}

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
  [[ -f "$1" ]] || test_die "Generated file '$1' not found!"
}

#######################################################################
test_step "Initial folder structure cleanup and preparation"
reset_root

#######################################################################
test_step "First minimal run of qesap.py"
qesap.py --version || test_die "qesap.py not in PATH"

#######################################################################
test_step "Global help"
qesap.py --help || test_die "qesap.py help failure"

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                      C O N F I G U R E                          ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Configure help"
qesap.py configure --help || test_die "qesap.py configure help failure"

#######################################################################
QESAP_CFG=test_1.yaml
test_step "[${QESAP_CFG}] Configure has to fail with empty yaml"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure
rc=$?; [[ $rc -ne 0 ]] || test_die "Should exit with zero rc but is rc:$rc"
set -e

#######################################################################
QESAP_CFG=test_2.yaml
test_step "[${QESAP_CFG}] Minimal configure only with Terraform"
reset_root
# `qesap.py configure` generate a terraform.tfvars file
# in the provider folder indicated in the conf.yaml
# and with content from the conf.yaml terraform section
# Also test different YAML to TFVARS data type conversions
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} should exit with zero rc but is rc:$?"
TEST_TERRAFORM_TFVARS="${TEST_PROVIDER}/terraform.tfvars"
test_file "${TEST_TERRAFORM_TFVARS}"
grep -qE "fruit_string.*=.*\"lampone\"" "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml: string conversion"
grep -qE "fruit_string_noquot.*=.*\"lampone\"" "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml: string conversion noquot"
grep -qE "fruit_int = 42" "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml: int conversion"
grep -qE "fruit_bool = true" "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml: bool conversion"
grep -qE "fruit_list.*=.*\[\"10.*\]" "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from test_2.yaml: list conversion"

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] configure with also Ansible"
# `qesap.py configure` generate some ansible .yaml files
reset_root
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} should exit with zero rc but is rc:$?"
TEST_ANSIBLE_MEDIA="${TEST_ANSIBLE_VARS}/hana_media.yaml"
test_file "${TEST_ANSIBLE_MEDIA}"
grep -q corniolo "${TEST_ANSIBLE_MEDIA}" || test_die "${TEST_ANSIBLE_MEDIA} generated from test_3.yaml should contain the corniolo"

#######################################################################
QESAP_CFG=test_5.yaml
test_step "[${QESAP_CFG}] Change a setting in place"
# This test try to reproduce the situation in which
# a user run `qesap.py conf.yaml` a first time
# then tune and change something in the config.yaml
# and run the `qesap.py conf.yaml` a second time
# to have the changes applied in the generated .tfvars or ansible files
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} should exit with zero rc but is rc:$?"
grep -q lampone "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from ${QESAP_CFG} should contain the world lampone"

test_split
QESAP_CFG=test_6.yaml
# test_6 has everything the same as test_5 except for a terraform variable,
# verify that running the configure command in place result in the .tfvars file to change
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "Should exit with zero rc but is rc:$?"
test_file "${TEST_TERRAFORM_TFVARS}"
set +e
grep -q lampone "${TEST_TERRAFORM_TFVARS}"
rc=$?; [[ $rc -ne 0 ]] || test_die "${TEST_TERRAFORM_TFVARS} generated from ${QESAP_CFG} should no more contain the world lampone"
set -e
grep -q papaya "${TEST_TERRAFORM_TFVARS}" || test_die "${TEST_TERRAFORM_TFVARS} generated from ${QESAP_CFG} should contain the world papaya"

#######################################################################
QESAP_CFG=test_1.yaml
test_step "[${QESAP_CFG}] test stdout for configure FAIL"
# can run without verbosity and if ok print anything
LOGNAME="${QESAPROOT}/test_configure.txt"
rm "${LOGNAME}" || echo "No ${LOGNAME} to delete"
set +e
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} configure |& tee "${LOGNAME}"

grep -qE "^DEBUG" "${LOGNAME}"
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc in verbose mode there should be any DEBUG"

grep -qE "^INFO" "${LOGNAME}"
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc in verbose mode there should be any INFO"

grep -qE "^ERROR" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some ERROR"
set -e
rm "${LOGNAME}"

#######################################################################
test_step "[${QESAP_CFG}] test stdout with verbose for configure FAIL"
rm "${LOGNAME}" || echo "No ${LOGNAME} to delete"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure |& tee "${LOGNAME}"

grep -qE "^DEBUG" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

grep -qE "^ERROR" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some ERROR"
set -e
rm "${LOGNAME}"

#######################################################################
QESAP_CFG=test_5.yaml
test_step "[${QESAP_CFG}] test stdout for configure PASS"
rm "${LOGNAME}" || echo "No ${LOGNAME} to delete"
# can run without verbosity and if ok print anything
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} configure |& tee "${LOGNAME}"

lines=$(cat "${LOGNAME}" | wc -l)
[[ $lines -eq 0 ]] || test_die "${LOGNAME} should be empty but has $lines lines"
rm "${LOGNAME}"

#######################################################################
test_step "[${QESAP_CFG}] test stdout with verbosity for configure PASS"
rm "${LOGNAME}" || echo "No ${LOGNAME} to delete"
# run the same with verbosity
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure |& tee "${LOGNAME}"

grep -qE "^DEBUG" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"
rm "${LOGNAME}"

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                      T E R R A F O R M                          ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Terraform help"
qesap.py terraform --help || test_die "qesap.py terraform help failure"

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] Terraform FAILURE for invalid code in main.tf"
# Create an invalid main.tf.
# The non zero exit code from terraform has to be correctly propagated
# through the qesap.py
echo "SOMETHING INVALID" > "${TEST_PROVIDER}/main.tf"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform
rc=$?; [[ $rc -ne 0 ]] || test_die "Should exit with non zero rc but is rc:$rc"
set -e
rm -rf "${TEST_PROVIDER}"

#######################################################################
test_step "[${QESAP_CFG}] Run dryrun Terraform"
# correct execution of terraform in dryrun mode:
# 1. test is checking for 0 exit code
# 2. for skipping generation of the terraform.tfstate
# Test is using an empty main.tf placed in the right provider folder
reset_root
touch "${TEST_PROVIDER}/main.tf"
THIS_LOG="${QESAPROOT}/test_3_terraform.log"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform || test_die "${QESAP_CFG} fail on dryrun terraform"
TEST_TERRAFORM_TFSTATE="${TEST_PROVIDER}/terraform.tfstate"
[[ ! -f "${TEST_TERRAFORM_TFSTATE}" ]] || test_die "File ${TEST_TERRAFORM_TFSTATE} has not to be generated in dryrun mode!"

test_split
echo "Run the script again collecting the output"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform  |& tee "${THIS_LOG}"
for t_step in init plan apply; do
  echo "***Detect ${t_step} command***"
  grep -qE "terraform.*${t_step}" \
    "${THIS_LOG}" || test_die "${QESAP_CFG} terraform dryrun does not have expected ${t_step} command in the output"
done
terraform_invocations=$(cat "${THIS_LOG}" | wc -l)
[[ $terraform_invocations -eq 3 ]] || test_die "terraform dryrun does not emit exactly 3 commands but ${terraform_invocations}"
[[ ! -f "${TEST_TERRAFORM_TFSTATE}" ]] || test_die "File ${TEST_TERRAFORM_TFSTATE} has not to be generated"
rm ${THIS_LOG}
rm -rf "${TEST_PROVIDER}"

#######################################################################
test_step "[${QESAP_CFG}] Run Terraform"
# correct execution of terraform: test is checking for 0 exit code
# and for the generation of the terraform.tfstate
# terraform.tfstate is directly created by the terraform executable
reset_root
cp main_local.tf "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform || test_die "${QESAP_CFG} fail on terraform"
test_file "${TEST_TERRAFORM_TFSTATE}"
test_file "${TEST_PROVIDER}/foo.bar"
# do not delete tfstate to lave them fo rthe next test

#######################################################################
test_step "[${QESAP_CFG}] Run dryrun Terraform destroy"
# correct execution of terraform destroy in dryrun mode:
# 1. test is checking for 0 exit code
THIS_LOG="${QESAPROOT}/test_3_terraform.log"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform -d || test_die "${QESAP_CFG}l fail on dryrun terraform destroy"

test_split
echo "Run the script again collecting the output"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform -d |& tee "${THIS_LOG}"
echo "***Detect destroy command***"
grep -qE "terraform.*destroy" \
  "${THIS_LOG}" || test_die "${QESAP_CFG} terraform dryrun does not have expected destroy command in the output"

terraform_invocations=$(cat "${THIS_LOG}" | wc -l)
[[ $terraform_invocations -eq 1 ]] || test_die "terraform dryrun does not emit exactly 1 command but ${terraform_invocations}"
test_file "${TEST_TERRAFORM_TFSTATE}"
test_file "${TEST_PROVIDER}/foo.bar"
rm ${THIS_LOG}

#######################################################################
test_step "[${QESAP_CFG}] Run Terraform destroy"
# correct execution of terraform: test is checking for 0 exit code
# and for the generation of the terraform.tfstate
# terraform.tfstate is directly created by the terraform executable
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform || test_die "${QESAP_CFG} fail on terraform"
test_file "${TEST_TERRAFORM_TFSTATE}"
test_file "${TEST_PROVIDER}/foo.bar"

echo "--- NOW DESTROY ---"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -d || test_die "${QESAP_CFG} fail on terraform destroy"
test_file "${TEST_TERRAFORM_TFSTATE}"
[[ ! -f "${TEST_PROVIDER}/foo.bar" ]] || test_die "Resource ${TEST_PROVIDER}/foo.bar has not to be deleted when calling terraform destroy"
rm "${TEST_TERRAFORM_TFSTATE}"

#######################################################################
test_step "[${QESAP_CFG}] Run dryrun Terraform workspace"
# correct execution of terraform with workspaces in dryrun mode:
THIS_LOG="${QESAPROOT}/test_3_terraform.log"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform -w DONALDUCK || test_die "${QESAP_CFG} fail on dryrun terraform workspace"
TEST_TERRAFORM_TFSTATE="${TEST_PROVIDER}/terraform.tfstate"
[[ ! -f "${TEST_TERRAFORM_TFSTATE}" ]] || test_die "File ${TEST_TERRAFORM_TFVARS} has been generated but it should not be in dryrun mode!"

test_split
echo "Run the script again collecting the output"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform -w DONALDUCK |& tee "${THIS_LOG}"
for t_step in init workspace plan apply; do
  echo "***Detect ${t_step} command***"
  grep -qE "terraform.*${t_step}" \
    "${THIS_LOG}" || test_die "${QESAP_CFG} terraform workspace dryrun does not have expected ${t_step} command in the output"
done
rm ${THIS_LOG}

#######################################################################
test_step "[${QESAP_CFG}] Run Terraform with workspaces"

# Test is using an empty main.tf placed in the right provider folder
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -w DONALDUCK || test_die "${QESAP_CFG} fail on terraform with workspace"
ls -lai "${TEST_PROVIDER}"

[[ ! -f "${TEST_TERRAFORM_TFSTATE}" ]] || test_die "File ${TEST_TERRAFORM_TFVARS} has been generated but it should not"
[[ -d "${TEST_TERRAFORM_TFSTATE}.d" ]] || test_die "Folder ${TEST_TERRAFORM_TFVARS}.d has not been generated"

#######################################################################
test_step "[${QESAP_CFG}] Run Terraform destroy with workspaces"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -w DONALDUCK -d || test_die "${QESAP_CFG} fail on terraform destroy with workspace"
rm -rf "${TEST_TERRAFORM_TFSTATE}.d"

#######################################################################
test_step "[${QESAP_CFG}] test stdout for terraform PASS"
# run `qesap.py terraform` both with and without `--verbose`
# - The stdout in --verbose has to have some strings starting with both DEBUG and INFO
# - in case of pass and without --verbose, `qesap.py terraform` has not to emit any line

# run in non verbose mode
THIS_LOG="${QESAPROOT}/test_terraform.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} terraform |& tee "${THIS_LOG}"

lines=$(cat "${THIS_LOG}" | wc -l)
[[ $lines -eq 0 ]] || test_die "${THIS_LOG} should be empty but has $lines lines"
rm "${THIS_LOG}"

#######################################################################
test_step "[${QESAP_CFG}] test stdout with verbosity for terraform PASS"
THIS_LOG="${QESAPROOT}/test_terraform_verbose.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
# now repeat exactly the same in --verbose mode
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform |& tee "${THIS_LOG}"

set +e
grep -qE "^DEBUG" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

# check for duplicated lines
lines=$(grep -c "Apply complete!" "${THIS_LOG}")
[[ $lines -eq 1 ]] || test_die "${THIS_LOG} there is one message in the log repeated $lines times."
set -e
rm "${THIS_LOG}"

#######################################################################
test_step "[${QESAP_CFG}] test .log.txt file redirection"
# run `qesap.py terraform` both with and without `--verbose`
# - `qesap.py terraform` redirect all the terraform stdout and stderr for each of the
#    executed terraform command (init, plan and apply) to a dedicated log file

# run in non verbose mode
rm terraform.*.log.txt || echo "No terraform.*.log.txt to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} terraform || test_die "Error in terraform execution"

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
rm terraform.*.log.txt

#######################################################################
test_step "[${QESAP_CFG}] test .log.txt file redirection with verbosity"
# now repeat exactly the same in --verbose mode
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
rm terraform.*.log.txt

#######################################################################
test_step "[${QESAP_CFG}] test .log.txt file redirection in case of error"
rm terraform.*.log.txt || echo "No terraform.*.log.txt to delete"
echo "SOMETHING INVALID" > "${TEST_PROVIDER}/main.tf"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform
set -e
THIS_LOG="terraform.init.log.txt"
lines=$(cat "${THIS_LOG}" | wc -l)
[[ $lines -ne 0 ]] || test_die "${THIS_LOG} should not be empty"
grep -E "SOMETHING INVALID" $THIS_LOG || test_die "Expected content not found in ${THIS_LOG}"
rm terraform.*.log.txt
rm "${TEST_PROVIDER}/main.tf"

#######################################################################
test_step "[${QESAP_CFG}] test parallel dryrun"

THIS_LOG="${QESAPROOT}/test_parallel.txt"
reset_root
cp main_local_many.tf "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform --parallel 1 |& tee "${THIS_LOG}"
grep -E "plan.*-parallelism=1" ${THIS_LOG} || test_die "Missing argument -parallelism=1 in terraform plan"
grep -E "apply.*-parallelism=1" ${THIS_LOG} || test_die "Missing argument -parallelism=1 in terraform apply"
rm ${THIS_LOG}

#######################################################################
test_step "[${QESAP_CFG}] test parallel"

# run reference test without parallel
reset_root
cp main_local_many.tf "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform |& tee "${THIS_LOG}"
grep local-exec ${THIS_LOG}
for foofile in "${TEST_PROVIDER}"/foo.*; do
  printf "#${foofile} --> $(cat ${foofile})#\n"
done
count=$(grep -rhE "^@.*foo@" "${TEST_PROVIDER}" | sort -u | wc -l)
[[ $count -eq 1 ]] || test_die "Not all the generated files has the same content. Count:${count}"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -d
rm ${THIS_LOG}

test_split

reset_root
cp main_local_many.tf "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform --parallel 1 |& tee "${THIS_LOG}"
grep local-exec ${THIS_LOG}
for foofile in "${TEST_PROVIDER}"/foo.*; do
  printf "#${foofile} --> $(cat ${foofile})#\n"
done
count=$(grep -rhE "^@.*foo@" "${TEST_PROVIDER}" | sort -u | wc -l)
[[ $count -ne 1 ]] || test_die "All the generated files has the same content. Count:${count}"
rm ${THIS_LOG}


echo "#######################################################################"
echo "###                                                                 ###"
echo "###                         A N S I B L E                           ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Ansible help"
qesap.py ansible --help || test_die "qesap.py ansible help failure"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible without inventory"
# Ansible without inventory is expected to fails, all other part of the conf.yaml are valid.
rm "${TEST_PROVIDER}/inventory.yaml" || echo "No old inventory to remove"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible
rc=$?; [[ $rc -ne 0 ]] || test_die "qesap.py ansible has to fail without inventory.yaml but rc:$rc"
set -e

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[$QESAP_CFG] Run Ansible with no playbooks"
# "qesap.py ... ansible" should run doing nothing if:
#  no playbooks has to be played --> no playbook in the create: section of the conf.yaml
# Keep in mind that test_3.yaml has no playbooks at all
# This test is about a not ok conf.yaml
touch "${TEST_PROVIDER}/inventory.yaml"
rm ansible.*.log.txt || echo "Nothing to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
[[ $ansible_logs_number -eq 0 ]] || test_die "ansible .log.txt are not 0 files but has ${ansible_logs_number}"

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible with no playbooks and verbosity"
# exactly same as the previous one but with "--verbose"
rm ansible.*.log.txt || echo "Nothing to delete"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
[[ $ansible_logs_number -eq 0 ]] || test_die "ansible .log.txt are not 0 files but has ${ansible_logs_number}"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible dryrun"
THIS_LOG="${QESAPROOT}/ansible.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} fail on configure"
rm ansible.*.log.txt || echo "Nothing to delete"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible || test_die "${QESAP_CFG} fail on ansible"

test_split
echo "Run the script again collecting the output"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible |& tee "${THIS_LOG}"
grep -E "ansible.*-i.*${PROVIDER}/inventory.yaml.*all.*ssh-extra-args=\".*\"" \
    "${THIS_LOG}" || test_die "${QESAP_CFG} dryrun fails in first ansible command"
grep -E "ansible.*-i.*${PROVIDER}/inventory.yaml.*all.*sudo.*true" \
    "${THIS_LOG}" || test_die "${QESAP_CFG} dryrun fails in second ansible command"
grep -E "ansible-playbook.*-i.*${PROVIDER}/inventory.yaml.*ansible/playbooks/sambuconero.yaml" \
    "${THIS_LOG}" || test_die "${QESAP_CFG} dryrun fails in ansible-playbook command"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
[[ $ansible_logs_number -eq 0 ]] || test_die "ansible .log.txt are not 0 files but has ${ansible_logs_number}"
rm "${THIS_LOG}"
rm "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
rm "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible dryrun junit"
# --junit also add a mkdir command at the beginning of the sequence
THIS_LOG="${QESAPROOT}/ansible.log"
THIS_REPORT_DIR="${QESAPROOT}/junit_reports"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
rm -rf "${THIS_REPORT_DIR}" || echo "No ${THIS_REPORT_DIR} to delete"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} fail on configure"
rm ansible.*.log.txt || echo "Nothing to delete"
test_split
# Start by checking that mkdir is not in the command list if --junit is NOT used
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible |& tee "${THIS_LOG}"
set +e
grep -q mkdir "${THIS_LOG}"
rc=$?; [[ $rc -ne 0 ]] || test_die "Command sequence in ${THIS_LOG} has not to contain mkdir, as --junit is not used"
set -e
test_split
# Now try again but this time using --junit
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible --junit ${THIS_REPORT_DIR} |& tee "${THIS_LOG}"
set +e
grep -q mkdir "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "Command sequence in ${THIS_LOG} has to contain mkdir, as --junit is used"
set -e
[[ ! -d "${THIS_REPORT_DIR}" ]] || test_die "--dryrun has not to create any folder in ${THIS_REPORT_DIR}"
test_split
# Try again but now create the folder in advance: mkdir should be skipped
mkdir ${THIS_REPORT_DIR}
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible --junit ${THIS_REPORT_DIR} |& tee "${THIS_LOG}"
set +e
grep -q mkdir "${THIS_LOG}"
rc=$?; [[ $rc -ne 0 ]] || test_die "Command sequence in ${THIS_LOG} has not to contain mkdir, as --junit is used but folder was already there"
set -e
rm "${THIS_LOG}"
rm "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
rm "${TEST_PROVIDER}/inventory.yaml"
rm -rf "${THIS_REPORT_DIR}"

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible PASS"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} fail on configure"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"

#######################################################################
test_step "[${QESAP_CFG}] Ansible stdout in case of PASS"
THIS_LOG="${QESAPROOT}/test_ansible_pass.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible |& tee "${THIS_LOG}"
lines=$(cat "${THIS_LOG}" | wc -l)
echo "--> lines:${lines}"
[[ $lines -eq 0 ]] || test_die "${THIS_LOG} should be empty but has ${lines} lines"
rm "${THIS_LOG}"
rm "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
rm "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
test_step "[${QESAP_CFG}] Ansible stdout with verbosity in case of PASS"
THIS_LOG="${QESAPROOT}/test_ansible_pass_verbose.txt"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible |& tee "${THIS_LOG}"
set +e
grep -qE "^DEBUG" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${THIS_LOG}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"

task_occurrence=$(grep -cE "TASK \[Say hello\]" "${THIS_LOG}")
echo "--> task_occurrence:${task_occurrence}"
[[ $task_occurrence -eq 1 ]] || test_die "Some Ansible stdout lines are repeated ${task_occurrence} times in place of exactly 1"
set -e
# check presence of the subprocess .log.txt
ansible_logs_number=$(find . -type f -name "ansible.sambuconero.log.txt" | wc -l)
[[ $ansible_logs_number -eq 1 ]] || test_die "ansible.sambuconero.log.txt missing"
# check content of the subprocess .log.txt
grep -E "TASK.*Say hello" ansible.sambuconero.log.txt || test_die "Expected content not found in ansible.sambuconero.log.txt"
rm "${THIS_LOG}"
rm ansible.*.log.txt
rm "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
rm "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_6.yaml
test_step "[${QESAP_CFG}] Check redirection to file of ansible-playbook logs"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/timbio.yaml"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/buga.yaml"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/purace.yaml"
cp inventory.yaml "${TEST_PROVIDER}/"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
echo "--> ansible_logs_number:${ansible_logs_number}"
# 3 playbooks means 3 logs
[[ $ansible_logs_number -eq 3 ]] || test_die "ansible .log.txt are not 3 files but has ${ansible_logs_number}"
rm ansible.*.log.txt
rm "${QESAPROOT}/ansible/playbooks/timbio.yaml"
rm "${QESAPROOT}/ansible/playbooks/buga.yaml"
rm "${QESAPROOT}/ansible/playbooks/purace.yaml"
rm "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_7.yaml # This is a conf.yaml with a playbook that always fails
test_step "[${QESAP_CFG}] Check redirection to file of ansible-playbook logs in case of error in the playbook execution"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp marasca.yaml "${QESAPROOT}/ansible/playbooks/"
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible
rc=$?; [[ $rc -ne 0 ]] || test_die "qesap.py ansible has to fail if ansible-playbook fails rc:$rc"
set -e
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
# 2 playbooks means 2 logs
[[ $ansible_logs_number -eq 2 ]] || test_die "ansible .log.txt are not 2 files but has ${ansible_logs_number}"
grep -E "TASK.*Say hello" ansible.sambuconero.log.txt || test_die "Expected content not found in ansible.sambuconero.log.txt"
grep -E "TASK.*This fails" ansible.marasca.log.txt || test_die "Expected content not found in ansible.marasca.log.txt"

rm ansible.*.log.txt
rm "${QESAPROOT}/ansible/playbooks/sambuconero.yaml"
rm "${QESAPROOT}/ansible/playbooks/marasca.yaml"
rm "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible with --junit"
reset_root
THIS_REPORT_DIR="${QESAPROOT}/junit_reports/nested/nested"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
find . -type f -name "sambuconero*.xml" -delete || echo "Nothing to delete"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --junit ${THIS_REPORT_DIR} || test_die "${QESAP_CFG} fail on ansible"
junit_logs_number=$(find . -type f -name "sambuconero*.xml" | wc -l)
echo "--> junit_logs_number:${junit_logs_number}"
[[ $junit_logs_number -eq 1 ]] || test_die "ansible JUNIT reports should be 1 files but are ${junit_logs_number}"
find . -type f -name "sambuconero*.xml" -delete
rm -rf ${THIS_REPORT_DIR}

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible with --profile"
rm ansible.*.log.txt || echo "Nothing to delete"
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --profile \
  || test_die "${QESAP_CFG} fail on ansible with --profile"
set +e
time_reports=$(grep -cE " -+ [0-9.]+s" ansible.goji.log.txt)
echo "--> time_reports:${time_reports}"
set -e
[[ $time_reports -gt 1 ]] || test_die "ansible profile reports should be at least 1 but is ${time_reports}"
rm ansible.*.log.txt

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible with --profile and --junit"
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --profile --junit . \
  || test_die "${QESAP_CFG} fail on ansible with --profile and --junit"
junit_logs_number=$(find . -type f -name "goji*.xml" | wc -l)
echo "--> junit_logs_number:${junit_logs_number}"
[[ $junit_logs_number -eq 1 ]] || test_die "ansible JUNIT reports should be 1 files but are ${junit_logs_number}"
set +e
time_reports=$(grep -cE " -+ [0-9.]+s" ansible.goji.log.txt) || test_die "Test fails at profile output check"
echo "--> time_reports:${time_reports}"
set -e
[[ $time_reports -gt 1 ]] || test_die "ansible profile reports should be at least 1 but is ${time_reports}"
rm ansible.*.log.txt
find . -type f -name "goji*.xml" -delete

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible with --sequence create/destroy and apiver:3"
# --sequence option is also supported when using conf.yaml with apiver:3
# but only create and destroy are supported as name
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
find . -type f -name "ribes*.xml" -delete || echo "Nothing to delete"
reset_root
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence create \
  || test_die "${QESAP_CFG} fail on ansible with --sequence create"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence destroy \
  || test_die "${QESAP_CFG} fail on ansible with --sequence destroy"

junit_logs_number=$(find . -type f -name "goji*.xml" | wc -l)
echo "--> junit_logs_number:${junit_logs_number}"
[[ $junit_logs_number -eq 0 ]] || test_die "ansible JUNIT reports should not be generated but are ${junit_logs_number}"
rm ansible.*.log.txt

#######################################################################
test_step "[${QESAP_CFG}] Fails running Ansible with --sequence other than create/destroy and apiver:3"
# --sequence option is also supported when using conf.yaml with apiver:3
# but only create and destroy are supported as name
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
find . -type f -name "ribes*.xml" -delete || echo "Nothing to delete"
reset_root
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

# This is expected to fail
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence something
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc script is expected to fails using conf.yaml with apiver:3 and --sequence other than create/destroy"
set -e

#######################################################################
test_step "[${QESAP_CFG}] Fails running Ansible both -d and --sequence"
# --sequence option is also supported when using conf.yaml with apiver:3
# but only create and destroy are supported as name
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
find . -type f -name "ribes*.xml" -delete || echo "Nothing to delete"
reset_root
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

# This is expected to fail
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible -d --sequence create
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc script is expected to fails when using -d and --sequence at the same time"
set -e

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible with --sequence not in create/destroy and apiver:3"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence something
rc=$?; [[ $rc -ne 0 ]] || test_die "${QESAP_CFG} fail on ansible with --sequence not in create/destroy"
set -e

#######################################################################
test_step "[${QESAP_CFG}] Run Ansible with --sequence not in create/destroy and apiver:4"
QESAP_CFG=test_9.yaml
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/test.yaml"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence test \
  || test_die "${QESAP_CFG} ansible with --sequence test"

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible destroy"
THIS_LOG="${QESAPROOT}/ansible.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
reset_root
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} fail on configure"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible create"
test_file "${FILE_TOUCH_BY_ANSIBLE}"
rm ansible.*.log.txt

test_split
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible -d || test_die "${QESAP_CFG} fail on ansible destroy"

test_split
echo "Run the script again collecting the output"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun ansible -d |& tee "${THIS_LOG}"
grep -E "ansible-playbook.*-i.*${PROVIDER}/inventory.yaml.*ansible/playbooks/ribes_nero.yaml" \
    "${THIS_LOG}" || test_die "${QESAP_CFG} dryrun fails in ansible-playbook command"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
[[ $ansible_logs_number -eq 0 ]] || test_die "ansible .log.txt are not 0 files but has ${ansible_logs_number}"
rm "${THIS_LOG}"

test_split
echo "Run the script again without dryrun"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible -d |& tee "${THIS_LOG}"
[[ ! -f "${FILE_TOUCH_BY_ANSIBLE}" ]] || test_die "File ${FILE_TOUCH_BY_ANSIBLE} has to be deleted by ribes_nero.yaml"


echo "#######################################################################"
echo "###                                                                 ###"
echo "###                           D E P L O Y                           ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Deploy help"
qesap.py deploy --help || test_die "qesap.py deploy help failure"

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run deploy dryrun"
THIS_LOG="${QESAPROOT}/deploy.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
reset_root
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun deploy || test_die "${QESAP_CFG} fail on deploy"

test_split
echo "Run the script again collecting the output"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun deploy |& tee "${THIS_LOG}"

set +e
count=$(grep -cE "terraform " "${THIS_LOG}")
[[ $count -eq 3 ]] || test_die "${THIS_LOG} there is not exactly 3 terraform lines but $count."

count=$(grep -cE "ansible " "${THIS_LOG}")
[[ $count -eq 2 ]] || test_die "${THIS_LOG} there are not exactly 2 ansible lines but $count."

count=$(grep -cE "ansible-playbook " "${THIS_LOG}")
[[ $count -eq 1 ]] || test_die "${THIS_LOG} there is not exactly 1 ansible-playbook line but $count."
set -e
rm "${THIS_LOG}"

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run deploy"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
reset_root

cp main_local.tf "${TEST_PROVIDER}/main.tf"
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} deploy |& tee "${THIS_LOG}"
test_file "${TEST_PROVIDER}/foo.bar"
test_file "${FILE_TOUCH_BY_ANSIBLE}"

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                         D E S T R O Y                           ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Deploy help"
qesap.py destroy --help || test_die "qesap.py deploy help failure"

#######################################################################
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun destroy |& tee -a "${THIS_LOG}"

test_split
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} destroy |& tee -a "${THIS_LOG}"
[[ ! -f "${TEST_PROVIDER}/foo.bar" ]] || test_die "File ${TEST_PROVIDER}/foo.bar has to be deleted by terraform"
[[ ! -f "${FILE_TOUCH_BY_ANSIBLE}" ]] || test_die "File ${FILE_TOUCH_BY_ANSIBLE} has to be deleted by ribes_nero.yaml"
