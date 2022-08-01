#!/bin/sh

set -e

function usage {
  echo "Usage:

  $0 -k <SSH key file>

Options
  k - SSH key: private SSH key that will be used to access the VM
  s - skip the Ansible configuration (all out of the registration)
  q - robustness adaptations to execute the script in openQA
  v - verbose mode
  h - print this help

Example:
  $0 -k ~/.ssh/id_rsa_cloud
" >&2
}

while getopts ":vhsqk:" options
  do
    case "${options}"
      in
        v)
          verbose=1
          ;;
        h)
           usage
           exit 0
           ;;
        k)
          ssh_key="${OPTARG}"
          ;;
        s)
          skip=1
          ;;
        q)
          quite=1
          ;;
        \?)
          echo "Invalid option: -${OPTARG}" >&2
          exit 1
          ;;
        :)
          echo "Option -${OPTARG} requires an argument." >&2
          exit 1
          ;;
        *)
          usage
          exit 1
          ;;
    esac
done

if [ -z "$1" ]
then
  usage
  exit 0
fi

if [ -z "${ssh_key}" ]
then
  echo "ssh key must be set"
  error=1
fi

if [ -z "${quite}" ]
then
  quite=0
fi

if [ -z "${skip}" ]
then
  skip=0
fi

if [ ! -f "${ssh_key}" ]
then
  echo "provided ssh key file couldn't be found"
  error=1
fi

if [ -n "${error}" ]
then
  exit 1
fi

. ./variables.sh

LogEx="log.txt"
TerraformPath="./terraform/${PROVIDER}"
AnsFlgs="-i ${TerraformPath}/inventory.yaml"
#AnsFlgs="${AnsFlgs} -vvvv"
AnsPlybkPath="./ansible/playbooks"

echo "--QE_SAP_DEPLOYMENT--"

### TERRAFORM BIT ###
if [ ${quite} -eq 1 ]
then
  TF_LOG_PATH=terraform.init."${LogEx}"  TF_LOG=INFO terraform -chdir="${TerraformPath}" init -no-color
  TF_LOG_PATH=terraform.plan."${LogEx}"  TF_LOG=INFO terraform -chdir="${TerraformPath}" plan -out=plan.zip -no-color
  TF_LOG_PATH=terraform.apply."${LogEx}" TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve plan.zip -no-color
else
  terraform -chdir="${TerraformPath}" apply -auto-approve
fi

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

ssh-add -v "${ssh_key}"

if [ ${quite} -eq 1 ]
then
  export ANSIBLE_NOCOLOR=True
  export ANSIBLE_LOG_PATH="$(pwd)/ansible.build.${LogEx}"
  export ANSIBLE_PIPELINING=True
fi

# Accept new ssh keys for ansible-controlled hosts
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"

# Run registration
ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"

# Option to quit if we don't want to run all plays
if [ ${skip} -eq 1 ]
then
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
