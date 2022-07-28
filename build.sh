#!/bin/bash
set -e

source variables.sh

TerraformPath="./terraform/${PROVIDER}"
AnsFlgs="-i ${TerraformPath}/inventory.yaml"
AnsPlybkPath="./ansible/playbooks"

### TERRAFORM BIT ###
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve

### ANSIBLE BIT ###
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"

# Run registration
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"

# Option to quit if we don't want to run all plays
if [[ $1 == 'skip' ]] ; then
  echo "Skipping build tasks"
  exit 0
fi

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml  -e "use_sapconf=${SAPCONF}"
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/cluster_sbd_prep.yaml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-storage.yaml 
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-download-media.yaml 
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-install.yaml 
