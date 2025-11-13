#!/bin/bash

# This is a library of shell functions
# It is intended to be sourced by other scripts, not executed directly.

# TROOT is expected to be set by the calling script to the root of the test directory.

QESAPROOT="${TROOT}/test_repo"
PROVIDER="fragola"
TEST_PROVIDER="${QESAPROOT}/terraform/${PROVIDER}"
TEST_ANSIBLE_VARS="${QESAPROOT}/ansible/playbooks/vars"
PATH="${TROOT}/../..":$PATH
E2E_ROOT="scripts/qesap/test/e2e"

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
  local exit_code=$?
  local message="$1"
  local error_log="$2"
  local line=$(caller 0 | awk '{print $1}')
  local file=$(caller 0 | awk '{print $3}')
  # Strip leading './' if it exists, to create a clean path for GitHub Actions
  file="${file#./}"

  if [[ "${GITHUB_ACTIONS}" == "true" ]]; then
    # 1. Report the primary failure in the test script itself
    echo "::error file=${E2E_ROOT}/${file},line=${line}::[exit code ${exit_code}] ${message}"

    # 2. If a log file is provided, parse it for detailed tool errors
    if [[ -f "${error_log}" ]]; then
      # This generic awk parser creates additional annotations from the log file.
      awk -v logfile="${E2E_ROOT}/${error_log}" '
        # Look for lines containing "error", "failed", or "fatal" (case-insensitive)
        /[Ee]rror|[Ff]ailed|[Ff]atal/ {
          # Create an annotation pointing to this line in the log file
          print "::error file=" logfile ",line=" NR "::" $0
        }
      ' "${error_log}"
    fi
  else
    # For local execution, print a clear message and the log file contents
    echo "ERROR in ${file} at line ${line} (exit code ${exit_code}): ${message}" >&2
    if [[ -f "${error_log}" ]]; then
      echo "--- Error Log: ${error_log} ---" >&2
      cat "${error_log}" >&2
      echo "--- End of Error Log ---" >&2
    fi
  fi

  exit 1
}

test_file () {
  [[ -f "$1" ]] || test_die "Generated file '$1' not found!"
}
