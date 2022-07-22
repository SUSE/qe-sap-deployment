#!/bin/bash

ErrChk() {
  if [[ $? -ne 0 ]] ; then
    echo "Command failed"
    exit 1
  fi
}

source variables.sh
ErrChk

TerraformPath="./terraform/${PROVIDER}"
AnsFlgs="-i ${TerraformPath}/inventory.yaml"
AnsPlybkPath="./ansible/playbooks"

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/deregister.yaml
ErrChk

terraform -chdir="${TerraformPath}" destroy -auto-approve
ErrChk