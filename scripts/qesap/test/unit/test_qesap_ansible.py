from unittest import mock
import os
import logging
log = logging.getLogger(__name__)

from qesap import main


@mock.patch("qesap.subprocess_run")
def test_ansible_create(run, base_args, tmpdir, create_inventory, create_playbooks):
    """
    Test that the ansible subcommand plays playbooks
    listed in the ansible::create part of the config.yml
    """
    provider = 'grilloparlante'
    config_content = f"""---
provider: {provider}
ansible:
    create:
        - get_cherry_wood.yaml
        - made_pinocchio_head.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['get_cherry_wood', 'made_pinocchio_head'])
    calls = []
    for playbook in playbook_list:
        calls.append(mock.call(['ansible-playbook', '-i', inventory, playbook]))

    assert main(args) == 0
    
    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_ansible_verbose(run, base_args, tmpdir, create_inventory, create_playbooks):
    """
    run with -vvvv if qesap ansible --verbose
    (probably not supported in qesap deploy/destroy)
    """
    provider = 'grilloparlante'
    config_content = f"""---
provider: {provider}
ansible:
    create:
        - get_cherry_wood.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)
    
    playbook_list = create_playbooks(['get_cherry_wood'])
    calls = []
    for playbook in playbook_list:
        calls.append(mock.call(['ansible-playbook', '-vvvv', '-i', inventory, playbook]))

    assert main(args) == 0
    
    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_ansible_missing_inventory(run, tmpdir, base_args):
    """
    Stop and return non zero if inventory is missing
    """
    config_content = f"""---
provider: grilloparlante
ansible:
    create:
        - get_cherry_wood.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    
    assert main(args) != 0
    
    run.assert_not_called()


@mock.patch("qesap.subprocess_run")
def test_ansible_no_playbooks(run, tmpdir, base_args, create_inventory):
    """
    If no playbooks are listed, Ansible is not called
    """
    provider = 'grilloparlante'
    config_content = f"""---
provider: {provider}
ansible:"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    assert main(args) == 0
    
    run.assert_not_called()


@mock.patch("qesap.subprocess_run")
def test_ansible_missing_playbook(run, tmpdir, base_args, create_inventory, create_playbooks):
    """
    ansible subcommand has not to run any commands if
    any of the playbooks YAML file referred in the config.yaml
    does not exist
    """
    provider = 'grilloparlante'
    config_content = f"""---
provider: {provider}
ansible:
    create:
        - get_cherry_wood.yaml
        - made_pinocchio_head.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)
    # create one out of two
    create_playbooks(['get_cherry_wood'])

    assert main(args) != 0
    
    run.assert_not_called()


@mock.patch("qesap.subprocess_run", side_effect = [(0, []),(1, [])])
def test_ansible_stop(run, tmpdir, base_args, create_inventory, create_playbooks):
    """
    Stop the sequence of playbook at first one
    that is failing and return non zero
    """
    provider = 'grilloparlante'
    config_content = f"""---
provider: {provider}
ansible:
    create:
        - get_cherry_wood.yaml
        - made_pinocchio_head.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['get_cherry_wood', 'made_pinocchio_head'])
    calls = []
    calls.append(mock.call(['ansible-playbook', '-i', inventory, playbook_list[0]]))

    assert main(args) != 0
    
    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_ansible_destroy(run, base_args, tmpdir, create_inventory, create_playbooks):
    """
    Test that ansible subcommand, called with -d,
    call the destroy list of playbooks
    """
    provider = 'grilloparlante'
    config_content = f"""---
provider: {provider}
ansible:
    create:
        - get_cherry_wood.yaml
        - made_pinocchio_head.yaml
    destroy:
        - plant_a_tree.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    args.append('-d')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['plant_a_tree'])
    calls = []
    for playbook in playbook_list:
        calls.append(mock.call(['ansible-playbook', '-i', inventory, playbook]))

    assert main(args) == 0
    
    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_ansible_env_reg(run, base_args, tmpdir, create_inventory, create_playbooks):
    """
    Replace email and code before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
    """
    provider = 'grilloparlante'
    config_content = """---
provider: grilloparlante
ansible:
    create:
        - registration.yaml -e reg_code=${reg_code} -e email_address=${email}
    variables:
        reg_code: 1234-5678-90XX
        email: mastro.geppetto@collodi.it
    """
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['registration'])
    calls = []
    ansible_cmd = ['ansible-playbook']
    ansible_cmd.append('-i')
    ansible_cmd.append(inventory)
    ansible_cmd.append(playbook_list[0])
    ansible_cmd.append('-e')
    ansible_cmd.append('reg_code=1234-5678-90XX')
    ansible_cmd.append('-e')
    ansible_cmd.append('email_address=mastro.geppetto@collodi.it')
    calls.append(mock.call(ansible_cmd))

    assert main(args) == 0
    
    run.assert_called()
    run.assert_has_calls(calls)



@mock.patch("qesap.subprocess_run")
def test_ansible_env_sapconf(run, base_args, tmpdir, create_inventory, create_playbooks):
    """
    Replace sapconf flag before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
    """
    provider = 'grilloparlante'
    config_content = """---
provider: grilloparlante
ansible:
    create:
        - sap-hana-preconfigure.yaml -e "use_sapconf=${sapconf}"
    variables:
        sapconf: True
    """
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['sap-hana-preconfigure'])
    calls = []
    ansible_cmd = ['ansible-playbook']
    ansible_cmd.append('-i')
    ansible_cmd.append(inventory)
    ansible_cmd.append(playbook_list[0])
    ansible_cmd.append('-e')
    ansible_cmd.append('"use_sapconf=True"')
    calls.append(mock.call(ansible_cmd))

    assert main(args) == 0
    
    run.assert_called()
    run.assert_has_calls(calls)


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