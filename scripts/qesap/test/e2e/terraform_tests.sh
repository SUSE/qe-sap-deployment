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
# remove the logs of a previous run: the checks below look for files that
# must not exist
rm -f terraform.*.log.txt terraform.*.log.json
cp main_local.tf "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform || test_die "${QESAP_CFG} fail on terraform"
test_file "${TEST_TERRAFORM_TFSTATE}"
test_file "${TEST_PROVIDER}/foo.bar"
# apply runs with '-json': it writes a .log.json file.
# init stays plain: 'terraform init -json' needs Terraform 1.9+, the project caps at 1.5.7.
# plan stays plain: 'terraform plan -json' does not write the resource attributes.
test_file "terraform.apply.log.json"
test_json_lines "terraform.apply.log.json"
for t_step in init plan; do
  [[ ! -f "terraform.${t_step}.log.json" ]] \
    || test_die "terraform.${t_step}.log.json must not exist (${t_step} is plain)"
done
# the apply log has the expected event types
for t_event in apply_start apply_complete change_summary outputs; do
  jq -r .type terraform.apply.log.json | grep -qx "${t_event}" \
    || test_die "terraform.apply.log.json has no ${t_event} event"
done
# the plain plan log has the resource attributes
grep -qE 'content +=  *"foo!"' terraform.plan.log.txt \
  || test_die "terraform.plan.log.txt does not have the attribute 'content' of local_file.foo"
# the plain apply log has the output values, as the plain 'terraform apply'
grep -qx "Outputs:" terraform.apply.log.txt \
  || test_die "terraform.apply.log.txt does not have the 'Outputs:' line"
grep -qE '^foo_filename = ".*/foo.bar"$' terraform.apply.log.txt \
  || test_die "terraform.apply.log.txt does not have the value of the output foo_filename"
grep -qx 'foo_list = tolist(\[' terraform.apply.log.txt \
  || test_die "terraform.apply.log.txt does not have the value of the output foo_list"
# the plain apply log does not repeat the plan
if grep -qE "Plan to " terraform.apply.log.txt; then
  test_die "terraform.apply.log.txt repeats the plan"
fi
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
rm terraform.*.log.txt terraform.*.log.json || echo "No terraform logs to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} terraform || test_die "Error in terraform execution"

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
# the plain log keeps its human-readable format
grep -qE "Apply complete!" terraform.apply.log.txt \
  || test_die "terraform.apply.log.txt does not contain 'Apply complete!'"
for t_step in plan apply; do
  if grep -qE '^[[:space:]]*\{' "terraform.${t_step}.log.txt"; then
    test_die "terraform.${t_step}.log.txt contains raw JSON lines"
  fi
done
# one .log.json for the only '-json' step (apply), none for init, plan or destroy
terraform_json_logs_number=$(find . -type f -name "terraform.*.log.json" | wc -l)
[[ $terraform_json_logs_number -eq 1 ]] || test_die "terraform .log.json are not 1 file but has ${terraform_json_logs_number}"
rm -f terraform.*.log.txt terraform.*.log.json

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test .log.txt file redirection with verbosity"
# now repeat exactly the same in --verbose mode
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform

find . -type f -name "terraform.*.log.txt" | grep . || test_die "No generated terraform .log.txt"
terraform_logs_number=$(find . -type f -name "terraform.*.log.txt" | wc -l)
[[ $terraform_logs_number -eq 3 ]] || test_die "terraform .log.txt are not 3 files but has ${terraform_logs_number}"
rm -f terraform.*.log.txt terraform.*.log.json

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test .log.txt file redirection in case of error"
rm terraform.*.log.txt terraform.*.log.json || echo "No terraform logs to delete"
reset_root
echo "SOMETHING INVALID" > "${TEST_PROVIDER}/main.tf"
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform
set -e
THIS_LOG="terraform.init.log.txt"
lines=$(cat "${THIS_LOG}" | wc -l)
[[ $lines -ne 0 ]] || test_die "${THIS_LOG} should not be empty"
grep -E "SOMETHING INVALID" $THIS_LOG || test_die "Expected content not found in ${THIS_LOG}"
# init and plan are plain and apply never ran: no .log.json file at all
for t_step in init plan apply; do
  [[ ! -f "terraform.${t_step}.log.json" ]] \
    || test_die "terraform.${t_step}.log.json must not exist"
done
rm -f terraform.*.log.txt terraform.*.log.json
rm "${TEST_PROVIDER}/main.tf"

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test apply .log.txt in case of error"
# The error happens in 'apply' (the '-json' step): the plan is valid, but
# terraform cannot create a folder in /proc.
rm terraform.*.log.txt terraform.*.log.json || echo "No terraform logs to delete"
reset_root
cat > "${TEST_PROVIDER}/main.tf" <<'EOF'
resource "local_file" "bad" {
  content  = "bad"
  filename = "/proc/qesap_e2e/bad.txt"
}
EOF
set +e
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform
rc=$?
set -e
[[ $rc -ne 0 ]] || test_die "qesap.py terraform must fail when apply fails"
THIS_LOG="terraform.apply.log.txt"
test_file "${THIS_LOG}"
test_file "terraform.apply.log.json"
# the plain apply log has the error, the resource and the source location
grep -qE "^Error: " "${THIS_LOG}" || test_die "${THIS_LOG} does not have the error"
grep -qE "^  with local_file.bad,$" "${THIS_LOG}" || test_die "${THIS_LOG} does not have the resource address of the error"
grep -qE "^  on main.tf line [0-9]+" "${THIS_LOG}" || test_die "${THIS_LOG} does not have the source location of the error"
rm -f terraform.*.log.txt terraform.*.log.json
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

#######################################################################
QESAP_CFG=test_3.yaml
test_step "[${QESAP_CFG}] test destroy does not use -json"
# destroy is plain: no '-json' flag, no .log.json file.
# The workspace steps are also plain, but test_3.yaml uses the default
# workspace, so they do not run here.
reset_root
# Empty configuration on purpose: this step checks the flags and the log
# files, not what destroy removes.
touch "${TEST_PROVIDER}/main.tf"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform >/dev/null \
  || test_die "${QESAP_CFG} fail on terraform before destroy"
THIS_LOG="${QESAPROOT}/test_destroy_plain.log"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun terraform -d |& tee "${THIS_LOG}"
if grep -qE '\-json' "${THIS_LOG}"; then
  test_die "destroy dryrun command must not contain -json"
fi
rm "${THIS_LOG}"
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} terraform -d \
  || test_die "${QESAP_CFG} fail on terraform destroy"
test_file "terraform.destroy.log.txt"
if [[ -f "terraform.destroy.log.json" ]]; then
  test_die "terraform.destroy.log.json must not be created for a plain step"
fi
rm -f terraform.*.log.txt terraform.*.log.json

