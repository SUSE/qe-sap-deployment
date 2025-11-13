#!/bin/bash

# This script contains tests for the 'terraform' command of qesap.py
# It is intended to be sourced by the main test.sh script

test_step "Terraform help"
qesap.py terraform --help || test_die "qesap.py terraform help failure"

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] Terraform FAILURE for invalid code in main.tf"
# Create an invalid main.tf.
# The non zero exit code from terraform has to be correctly propagated
# through the qesap.py
reset_root
echo "SOMETHING INVALID" > "${TEST_PROVIDER}/main.tf"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform
rc=$?; [[ $rc -ne 0 ]] || test_die "Should exit with non zero rc but is rc:$rc"
set -e
rm -rf "${TEST_PROVIDER}"

#######################################################################
QESAP_CFG=test_3.yaml
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
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform |& tee "${THIS_LOG}"
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
QESAP_CFG=test_3.yaml
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
QESAP_CFG=test_3.yaml
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
QESAP_CFG=test_3.yaml
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
QESAP_CFG=test_3.yaml
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
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] Run Terraform with workspaces"

# Test is using an empty main.tf placed in the right provider folder
reset_root
touch "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -w DONALDUCK || test_die "${QESAP_CFG} fail on terraform with workspace"
ls -lai "${TEST_PROVIDER}"

[[ ! -f "${TEST_TERRAFORM_TFSTATE}" ]] || test_die "File ${TEST_TERRAFORM_TFVARS} has been generated but it should not"
[[ -d "${TEST_TERRAFORM_TFSTATE}.d" ]] || test_die "Folder ${TEST_TERRAFORM_TFVARS}.d has not been generated"

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] Run Terraform destroy with workspaces"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -w DONALDUCK -d || test_die "${QESAP_CFG} fail on terraform destroy with workspace"
rm -rf "${TEST_TERRAFORM_TFSTATE}.d"

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test stdout for terraform PASS"
# run `qesap.py terraform` both with and without `--verbose`
# - The stdout in --verbose has to have some strings starting with both DEBUG and INFO
# - in case of pass and without --verbose, `qesap.py terraform` has not to emit any line

# run in non verbose mode
reset_root
touch "${TEST_PROVIDER}/main.tf"
THIS_LOG="${QESAPROOT}/test_terraform.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} terraform |& tee "${THIS_LOG}"

lines=$(cat "${THIS_LOG}" | wc -l)
[[ $lines -eq 0 ]] || test_die "${THIS_LOG} should be empty but has $lines lines"
rm "${THIS_LOG}"

#######################################################################
QESAP_CFG=test_3.yaml
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
QESAP_CFG=test_3.yaml
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
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test .log.txt file redirection with verbosity"
# now repeat exactly the same in --verbose mode
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
rm terraform.*.log.txt

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test .log.txt file redirection in case of error"
rm terraform.*.log.txt || echo "No terraform.*.log.txt to delete"
reset_root
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
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test parallel dryrun"

THIS_LOG="${QESAPROOT}/test_parallel.txt"
reset_root
cp main_local_many.tf "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform --parallel 1 |& tee "${THIS_LOG}"
grep -E "plan.*-parallelism=1" ${THIS_LOG} || test_die "Missing argument -parallelism=1 in terraform plan"
grep -E "apply.*-parallelism=1" ${THIS_LOG} || test_die "Missing argument -parallelism=1 in terraform apply"
rm ${THIS_LOG}

#######################################################################
QESAP_CFG=test_3.yaml
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

