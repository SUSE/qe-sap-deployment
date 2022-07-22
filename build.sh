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


### TERRAFORM BIT ###
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve
ErrChk

### ANSIBLE BIT ###
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml  -e "use_sapconf=${SAPCONF}"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/iscsi-server-configuration.yaml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-stroage.yml 
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-download-media.yaml 
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-install.yaml 
ErrChk
