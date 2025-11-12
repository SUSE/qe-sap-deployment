#!/bin/bash -e

TROOT=$(dirname "$0")
# shellcheck source=lib.sh
source "${TROOT}/lib.sh"

# Initial setup
test_step "Initial folder structure cleanup and preparation"
reset_root
test_step "First minimal run of qesap.py"
qesap.py --version || test_die "qesap.py not in PATH"
test_step "Global help"
qesap.py --help || test_die "qesap.py help failure"


run_tests() {
    for test_group in "$@"; do
        test_file="${TROOT}/${test_group}_tests.sh"
        if [ -f "$test_file" ]; then
            echo "======================================================================="
            echo "###                                                                 ###"
            echo "###                      Running test group: ${test_group^^}"
            echo "###                                                                 ###"
            echo "======================================================================="
            # shellcheck source=configure_tests.sh
            source "$test_file"
        else
            echo "Test group '$test_group' not found at '$test_file'"
            exit 1
        fi
    done
}

if [ "$#" -gt 0 ]; then
    run_tests "$@"
else
    run_tests configure terraform ansible deploy
fi

echo "#######################################################################"
echo "###                                                                 ###"
echo "###                        A L L   T E S T S                        ###"
echo "###                                                                 ###"
echo "###                           P A S S E D                           ###"
echo "###                                                                 ###"
echo "#######################################################################"