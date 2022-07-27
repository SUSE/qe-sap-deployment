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
#AnsFlgs="${AnsFlgs} -vvvv"
AnsPlybkPath="./ansible/playbooks"

echo "--QE_SAP_DEPLOYMENT--"

### TERRAFORM BIT ###
TF_LOG_PATH=terraform.init.log TF_LOG=INFO terraform -chdir="${TerraformPath}" init
ErrChk
TF_LOG_PATH=terraform.plan.log TF_LOG=INFO terraform -chdir="${TerraformPath}" plan -out=plan.zip
ErrChk
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve plan.zip
ErrChk

### ANSIBLE BIT ###
if [ -z ${SSH_AGENT_PID+x} ]
then
  echo "No SSH_AGENT_PID"
  eval $(ssh-agent)
else
  if ps -p $SSH_AGENT_PID > /dev/null
  then
    echo "ssh-agent is already running at ${SSH_AGENT_PID}"
  else
    echo "ssh-agent is NOT running at ${SSH_AGENT_PID}"
    eval $(ssh-agent)
  fi
fi

ssh-add -v /root/.ssh/id_rsa_cloud
ErrChk

#ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new -i /root/.ssh/id_rsa_cloud"
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/iscsi-server-configuration.yaml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-stroage.yml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-download-media.yaml
ErrChk

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-install.yaml
ErrChk
