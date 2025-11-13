#!/bin/bash

# This script contains tests for the 'deploy' and 'destroy' commands of qesap.py
# It is intended to be sourced by the main test.sh script

test_step "Deploy help"
qesap.py deploy --help || test_die "qesap.py deploy help failure"

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run deploy dryrun"
THIS_LOG="${QESAPROOT}/deploy.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
reset_root
cp goji.yaml ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"
FILE_TOUCH_BY_ANSIBLE="${QESAPROOT}/ansible/playbooks/goji.bacche"

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
THIS_LOG="${QESAPROOT}/deploy.log"
rm "${THIS_LOG}" || echo "No ${THIS_LOG} to delete"
reset_root

cp main_local.tf "${TEST_PROVIDER}/main.tf"
cp goji.yaml ribes_nero.yaml "${QESAPROOT}/ansible/playbooks/"
cp inventory.yaml "${TEST_PROVIDER}/"

# PATH trick is needed to use the local fake sudo shim
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} deploy |& tee "${THIS_LOG}"
test_file "${TEST_PROVIDER}/foo.bar"
test_file "${FILE_TOUCH_BY_ANSIBLE}"

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                         D E S T R O Y                           ###"
echo "###                                                                 ###"
echo "#######################################################################"
test_step "Destroy help"
PATH=$TROOT:$PATH qesap.py destroy --help || test_die "qesap.py destroy help failure"

#######################################################################
QESAP_CFG=test_8.yaml
test_step "[${QESAP_CFG}] Run destroy"
qesap.py -b ${QESAPROOT} -c ${QESAP_CFG} --dryrun destroy |& tee -a "${THIS_LOG}"

test_split
PATH=$TROOT:$PATH qesap.py --verbose -b ${QESAPROOT} -c ${QESAP_CFG} destroy |& tee -a "${THIS_LOG}"
[[ ! -f "${TEST_PROVIDER}/foo.bar" ]] || test_die "File ${TEST_PROVIDER}/foo.bar has to be deleted by terraform"
[[ ! -f "${FILE_TOUCH_BY_ANSIBLE}" ]] || test_die "File ${FILE_TOUCH_BY_ANSIBLE} has to be deleted by ribes_nero.yaml"
