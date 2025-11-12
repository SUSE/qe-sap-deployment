#!/bin/bash

# This is a library of shell functions
# It is intended to be sourced by other scripts, not executed directly.

# TROOT is expected to be set by the calling script to the root of the test directory.

QESAPROOT="${TROOT}/test_repo"
PROVIDER="fragola"
TEST_PROVIDER="${QESAPROOT}/terraform/${PROVIDER}"
TEST_ANSIBLE_VARS="${QESAPROOT}/ansible/playbooks/vars"
PATH="${TROOT}/../..":$PATH

reset_root () {
  echo "Clean and create folder structure for QESAPROOT in ${TROOT}"
  rm -rf "${TROOT}/test_repo"
  echo "TEST_PROVIDER:__${TEST_PROVIDER}__"
  mkdir -p "${TEST_PROVIDER}" "${TEST_ANSIBLE_VARS}"
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
