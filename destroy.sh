#!/bin/sh

set -e

function usage {
  echo "Usage:

  $0 -k <SSH key file>

Options
  k - SSH key: private SSH key that will be used to access the VM
  q - robustness adaptations to execute the script in openQA
  v - verbose mode
  h - print this help

Example:
  $0 -k ~/.ssh/id_rsa_cloud
" >&2
}

while getopts ":vhqk:" options
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

echo "--QE_SAP DESTROY--"


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
  export ANSIBLE_LOG_PATH="$(pwd)/ansible.destroy.${LogEx}"
fi

ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/deregister.yaml

### TERRAFORM BIT ###
if [ ${quite} -eq 1 ]
then
  TF_LOG_PATH=terraform.destroy."${LogEx}" TF_LOG=INFO terraform -chdir="${TerraformPath}" destroy -auto-approve -no-color
else
  terraform -chdir="${TerraformPath}" destroy -auto-approve
fi