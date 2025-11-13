#!/bin/bash

# This script contains tests for the 'ansible' command of qesap.py
# It is intended to be sourced by the main test.sh script

test_step "Ansible help"
qesap.py ansible --help || test_die "qesap.py ansible help failure"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible without inventory"
# Ansible without inventory is expected to fail, all other part of the conf.yaml are valid.
reset_root
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
reset_root
touch "${TEST_PROVIDER}/inventory.yaml"
rm ansible.*.log.txt || echo "Nothing to delete"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
[[ $ansible_logs_number -eq 0 ]] || test_die "ansible .log.txt are not 0 files but has ${ansible_logs_number}"

#######################################################################
QESAP_CFG=test_3.yaml
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
reset_root
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
rm "${THIS_LOG}" "${QESAPROOT}/ansible/playbooks/sambuconero.yaml" "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible dryrun junit"
# --junit also add a mkdir command at the beginning of the sequence
THIS_LOG="${QESAPROOT}/ansible.log"
THIS_REPORT_DIR="${QESAPROOT}/junit_reports"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
rm -rf "${THIS_REPORT_DIR}" || echo "No ${THIS_REPORT_DIR} to delete"
reset_root
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
rm "${THIS_LOG}" "${QESAPROOT}/ansible/playbooks/sambuconero.yaml" "${TEST_PROVIDER}/inventory.yaml"
rm -rf "${THIS_REPORT_DIR}"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible PASS"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
# PATH trick is needed to use the local fake sudo shim
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} fail on configure"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"

#######################################################################
QESAP_CFG=test_9.yaml
test_step "[${QESAP_CFG}] Ansible stdout in case of PASS"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/test.yaml"
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
THIS_LOG="${QESAPROOT}/test_ansible_pass.txt"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
PATH=$TROOT:$PATH qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible |& tee "${THIS_LOG}"
lines=$(cat "${THIS_LOG}" | wc -l)
echo "--> lines:${lines}"
[[ $lines -eq 0 ]] || test_die "${THIS_LOG} should be empty but has ${lines} lines"
rm "${THIS_LOG}" "${QESAPROOT}/ansible/playbooks/test.yaml" "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Ansible stdout with verbosity in case of PASS"
THIS_LOG="${QESAPROOT}/test_ansible_pass_verbose.txt"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible |& tee "${THIS_LOG}"
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
rm "${THIS_LOG}" ansible.*.log.txt "${QESAPROOT}/ansible/playbooks/sambuconero.yaml" "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_6.yaml
test_step "[${QESAP_CFG}] Check redirection to file of ansible-playbook logs"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/timbio.yaml"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/buga.yaml"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/purace.yaml"
cp inventory.yaml "${TEST_PROVIDER}/"
PATH=$TROOT:$PATH qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible"
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
echo "--> ansible_logs_number:${ansible_logs_number}"
# 3 playbooks means 3 logs
[[ $ansible_logs_number -eq 3 ]] || test_die "ansible .log.txt are not 3 files but has ${ansible_logs_number}"
rm ansible.*.log.txt "${QESAPROOT}/ansible/playbooks/timbio.yaml" "${QESAPROOT}/ansible/playbooks/buga.yaml" "${QESAPROOT}/ansible/playbooks/purace.yaml" "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_7.yaml # This is a conf.yaml with a playbook that always fails
test_step "[${QESAP_CFG}] Check redirection to file of ansible-playbook logs in case of error in the playbook execution"
reset_root
cp sambuconero.yaml marasca.yaml goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
set +e
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible
rc=$?; [[ $rc -ne 0 ]] || test_die "qesap.py ansible has to fail if ansible-playbook fails rc:$rc"
set -e
ansible_logs_number=$(find . -type f -name "ansible.*.log.txt" | wc -l)
# 2 playbooks means 2 logs
[[ $ansible_logs_number -eq 2 ]] || test_die "ansible .log.txt are not 2 files but has ${ansible_logs_number}"
grep -E "TASK.*Say hello" ansible.sambuconero.log.txt || test_die "Expected content not found in ansible.sambuconero.log.txt"
grep -E "TASK.*This fails" ansible.marasca.log.txt || test_die "Expected content not found in ansible.marasca.log.txt"

rm ansible.*.log.txt "${QESAPROOT}/ansible/playbooks/sambuconero.yaml" "${QESAPROOT}/ansible/playbooks/marasca.yaml" "${QESAPROOT}/ansible/playbooks/goji.yaml" "${TEST_PROVIDER}/inventory.yaml"

#######################################################################
QESAP_CFG=test_4.yaml
test_step "[${QESAP_CFG}] Run Ansible with --junit"
reset_root
THIS_REPORT_DIR="${QESAPROOT}/junit_reports/nested/nested"
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
find . -type f -name "sambuconero*.xml" -delete || echo "Nothing to delete"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --junit ${THIS_REPORT_DIR} || test_die "${QESAP_CFG} fail on ansible"
junit_logs_number=$(find . -type f -name "sambuconero*.xml" | wc -l)
echo "--> junit_logs_number:${junit_logs_number}"
[[ $junit_logs_number -eq 1 ]] || test_die "ansible JUNIT reports should be 1 files but are ${junit_logs_number}"
find . -type f -name "sambuconero*.xml" -delete
rm -rf ${THIS_REPORT_DIR}

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible with --profile"
reset_root
rm ansible.*.log.txt || echo "Nothing to delete"
cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --profile \
  || test_die "${QESAP_CFG} fail on ansible with --profile"
set +e
time_reports=$(grep -cE " -+ [0-9.]+s" ansible.goji.log.txt)
echo "--> time_reports:${time_reports}"
set -e
[[ $time_reports -gt 1 ]] || test_die "ansible profile reports should be at least 1 but is ${time_reports}"
rm ansible.*.log.txt

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible with --profile and --junit"
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --profile --junit . \
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
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible with --sequence create/destroy and apiver:3"
# --sequence option is also supported when using conf.yaml with apiver:3
# but only create and destroy are supported as name
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
find . -type f -name "ribes*.xml" -delete || echo "Nothing to delete"
reset_root
cp goji.yaml ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence create \
  || test_die "${QESAP_CFG} fail on ansible with --sequence create"

PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence destroy \
  || test_die "${QESAP_CFG} fail on ansible with --sequence destroy"

junit_logs_number=$(find . -type f -name "goji*.xml" | wc -l)
echo "--> junit_logs_number:${junit_logs_number}"
[[ $junit_logs_number -eq 0 ]] || test_die "ansible JUNIT reports should not be generated but are ${junit_logs_number}"
rm ansible.*.log.txt

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Fails running Ansible with --sequence other than create/destroy and apiver:3"
# --sequence option is also supported when using conf.yaml with apiver:3
# but only create and destroy are supported as name
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
find . -type f -name "ribes*.xml" -delete || echo "Nothing to delete"
reset_root
cp goji.yaml ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

# This is expected to fail
set +e
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence something
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc script is expected to fails using conf.yaml with apiver:3 and --sequence other than create/destroy"
set -e

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Fails running Ansible both -d and --sequence"
# --sequence option is also supported when using conf.yaml with apiver:3
# but only create and destroy are supported as name
rm ansible.*.log.txt || echo "Nothing to delete"
find . -type f -name "goji*.xml" -delete || echo "Nothing to delete"
find . -type f -name "ribes*.xml" -delete || echo "Nothing to delete"
reset_root
cp goji.yaml ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

# This is expected to fail
set +e
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible -d --sequence create
rc=$?; [[ $rc -ne 0 ]] || test_die "rc:$rc script is expected to fails when using -d and --sequence at the same time"
set -e

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible with --sequence not in create/destroy and apiver:3"
set +e
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence something
rc=$?; [[ $rc -ne 0 ]] || test_die "${QESAP_CFG} fail on ansible with --sequence not in create/destroy"
set -e

#######################################################################
QESAP_CFG=test_9.yaml
test_step "[${QESAP_CFG}] Run Ansible with --sequence not in create/destroy and apiver:4"
reset_root
cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/test.yaml"
cp inventory.yaml "${TEST_PROVIDER}/"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence test \
  || test_die "${QESAP_CFG} ansible with --sequence test"

#######################################################################
QESAP_CFG=test_9.yaml
test_step "[${QESAP_CFG}] Run Ansible with --sequence not defined in the config.yaml"

cp sambuconero.yaml "${QESAPROOT}/ansible/playbooks/test.yaml"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible --sequence ginepro \
  || test_die "${QESAP_CFG} ansible with --sequence test"

#######################################################################
QESAP_CFG=test_10.yaml
test_step "[${QESAP_CFG}] Run Ansible with variables in the config.yaml"

cp goji.yaml "${QESAPROOT}/ansible/playbooks/"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible \
  || test_die "${QESAP_CFG} ansible with variables test"
find . -type f -name "ansible.*.log.txt" -exec grep -E "extra_vars.*gineprino" {} + || test_die "String gineprino not found in ansible logs"

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run Ansible destroy"
THIS_LOG="${QESAPROOT}/ansible.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
reset_root
cp goji.yaml ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure || test_die "${QESAP_CFG} fail on configure"
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} ansible || test_die "${QESAP_CFG} fail on ansible create"
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
PATH=$TROOT:$PATH qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} ansible -d |& tee "${THIS_LOG}"
[[ ! -f "${FILE_TOUCH_BY_ANSIBLE}" ]] || test_die "File ${FILE_TOUCH_BY_ANSIBLE} has to be deleted by ribes_nero.yaml"
