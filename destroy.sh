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

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/deregister.yaml
#ErrChk

### TERRAFORM BIT ###
terraform -chdir="${TerraformPath}" destroy -auto-approve
ErrChk