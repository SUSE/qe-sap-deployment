#!/bin/bash

ErrChk() { 
  if [[ $? -ne 0 ]] ; then
    echo "Command failed"  
    exit 1
  fi
}

source variables.sh
ErrChk

AnsFlgs="-i ./terraform/${PROVIDER}/inventory.yaml"
AnsPlybkPath="./ansible/playbooks"

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/deregister.yaml
ErrChk

terraform -chdir=/Users/sstringer/code/qe-sap-deployment/terraform/azure destroy -auto-approve
ErrChk