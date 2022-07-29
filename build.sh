#!/bin/bash
set -e

source variables.sh

TerraformPath="./terraform/${PROVIDER}"
AnsFlgs="-i ${TerraformPath}/inventory.yaml"
#AnsFlgs="${AnsFlgs} -vvvv"
AnsPlybkPath="./ansible/playbooks"

echo "--QE_SAP_DEPLOYMENT--"

### TERRAFORM BIT ###
TF_LOG_PATH=terraform.init.log TF_LOG=INFO terraform -chdir="${TerraformPath}" init
TF_LOG_PATH=terraform.plan.log TF_LOG=INFO terraform -chdir="${TerraformPath}" plan -out=plan.zip
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve plan.zip

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

### ANSIBLE BIT ###
# Accept new ssh keys for ansible-controlled hosts
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"

# Run registration
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"

# Option to quit if we don't want to run all plays
if [[ $1 == 'skip' ]] ; then
  echo "Skipping build tasks"
  exit 0
fi

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/pre-cluster.yaml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/cluster_sbd_prep.yaml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-storage.yaml 
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-download-media.yaml 
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-install.yaml 
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-system-replication.yaml
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-system-replication-hooks.yaml

 
