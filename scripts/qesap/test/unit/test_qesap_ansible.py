from unittest import mock
import logging
log = logging.getLogger(__name__)

from qesap import main

def test_ansible(base_args, tmpdir):
    """
    Test the most common and simple execution of ansible:
     - ...
    """
    args = base_args(tmpdir)
    args.append('ansible')
    assert main(args) == 0


@mock.patch("qesap.subprocess_run")
def test_ansible_create(run, base_args, tmpdir):
    """
    Test that the ansible subcommand plays playbooks
    listed in the ansible::create part of the config.yml
    """
    provider = 'grilloparlante'
    config_content = """---
ansible:
    create:
        - get_cherry_wood.yaml
        - made_pinocchio_head.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name)
    args.append('ansible')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()
    terraform_path = f"./terraform/{provider}"
    ans_flgs = f"-i {terraform_path}/inventory.yaml"
    ans_plybk_path="./ansible/playbooks"
    calls = []
    calls.append(mock.call(f"ansible-playbook {ans_flgs} {ans_plybk_path}/get_cherry_wood.yaml"))
    calls.append(mock.call(f"ansible-playbook {ans_flgs} {ans_plybk_path}/made_pinocchio_head.yaml"))

    run.assert_has_calls(calls)


def test_ansible_verbose():
    """
    run with -vvvv if qesap ansible --verbose
    (probably not supported in qesap deploy/destroy)
    """
    pass


def test_ansible_missing_inventory():
    """
    Stop and return non zero if inventory is missing
    """
    pass


def test_ansible_missing_playbook():
    """
    ansible subcommand has not to run any commands if
    any of the playbooks YAML file referred in the config.yaml
    does not exist
    """
    pass


def test_ansible_stop():
    """
    Stop the sequence of playbook at first one
    that is failing and return non zero
    """
    pass


def test_ansible_env_reg():
    """
    Replace email and code before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
    """
    pass


def test_ansible_env_sapconf():
    """
    Replace sapconf flag before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
    """
    pass


def test_ansible_destroy():
    """
    Test that ansible subcommand, called with -d,
    call the destroy list of playbooks
    """
    pass


def test_ansible_no_playbooks():
    """
    If no playbooks are listed, Ansible is not called
    """
    pass


def test_ansible_ssh():
    """
    This stuff

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
fi
export ANSIBLE_PIPELINING=True

# Accept new ssh keys for ansible-controlled hosts
ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"

    """
    pass