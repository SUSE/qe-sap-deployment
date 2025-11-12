#!/bin/bash

# This script contains tests for the 'configure' command of qesap.py
# It is intended to be sourced by the main test.sh script

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
# This test tries to reproduce the situation in which
# a user run `qesap.py conf.yaml` a first time
# then tunes and changes something in the config.yaml
# and runs the `qesap.py conf.yaml` a second time
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
QESAP_CFG=test_1.yaml
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
QESAP_CFG=test_5.yaml
test_step "[${QESAP_CFG}] test stdout with verbosity for configure PASS"
rm "${LOGNAME}" || echo "No ${LOGNAME} to delete"
# run the same with verbosity
qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} configure |& tee "${LOGNAME}"

grep -qE "^DEBUG" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some DEBUG"

grep -qE "^INFO" "${LOGNAME}"
rc=$?; [[ $rc -eq 0 ]] || test_die "rc:$rc in verbose mode there should be some INFO"
rm "${LOGNAME}"
