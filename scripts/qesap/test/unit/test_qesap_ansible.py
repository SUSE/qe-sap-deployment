import os
from unittest import mock
import logging

from qesap import main


log = logging.getLogger(__name__)

ANSIBLE_EXE = '/bin/ansible'
ANSIBLEPB_EXE = '/paese/della/cuccagna/ansible-playbook'


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_create(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config, mock_call_ansibleplaybook):
    """
    Test that the ansible subcommand plays playbooks
    listed in the ansible::create part of the config.yml
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(playbooks['create'])
    calls = []
    for playbook in playbook_files_list:
        cmd = [ANSIBLEPB_EXE, '-i', inventory, playbook]
        calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_verbose(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config, mock_call_ansibleplaybook):
    """
    run with -vvvv if qesap ansible --verbose
    (probably not supported in qesap deploy/destroy)
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood']}

    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks['create'])
    calls = []
    for playbook in playbook_list:
        cmd = [ANSIBLEPB_EXE, '-vvvv', '-i', inventory, playbook]
        calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_dryrun(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config):
    """
    Command ansible does not call the Ansible executable in dryrun mode
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}

    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append('ansible')
    args.insert(0, '--dryrun')
    run.return_value = (0, [])
    create_inventory(provider)
    create_playbooks(playbooks['create'])

    assert main(args) == 0

    run.assert_not_called()


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_no_ansible(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config):
    """
    Command ansible with a deployment without
    the ansible: section in the congif.yaml

    If the user create a config.yaml without the ansible: section
    the `qesap.py ... ansible` command invocation has to fail.
    """
    provider = 'grilloparlante'
    config_content = f"""---
apiver: 2
provider: grilloparlante"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append('ansible')
    run.return_value = (0, [])

    assert main(args) == 1

    run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_missing_inventory(run, tmpdir, base_args, ansible_config):
    """
    Stop and return non zero if inventory is missing
    """
    config_content = ansible_config('grilloparlante', {'create': ['get_cherry_wood']})
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')

    assert main(args) != 0

    run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_no_playbooks(run, tmpdir, base_args, create_inventory, ansible_config):
    """
    If no playbooks are listed, Ansible is not called
    """
    provider = 'grilloparlante'

    config_content = ansible_config(provider, {})
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    create_inventory(provider)

    assert main(args) == 0

    run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_missing_playbook(run, tmpdir, base_args, create_inventory, create_playbooks, ansible_config):
    """
    ansible subcommand has not to run any commands if
    any of the playbooks YAML file referred in the config.yaml
    does not exist
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}
    config_content = ansible_config(provider, playbooks)

    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    create_inventory(provider)
    # create one out of two
    create_playbooks(playbooks['create'][0:1])

    assert main(args) != 0

    run.assert_not_called()


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run", side_effect=[(0, []), (1, [])])
def test_ansible_stop(run, _, tmpdir, base_args, create_inventory, create_playbooks, ansible_config, mock_call_ansibleplaybook):
    """
    Stop the sequence of playbook at first one
    that is failing and return non zero
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks['create'])
    calls = []
    cmd = [ANSIBLEPB_EXE, '-i', inventory, playbook_list[0]]
    calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) != 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_destroy(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config, mock_call_ansibleplaybook):
    """
    Test that ansible subcommand, called with -d,
    call the destroy list of playbooks
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head'], 'destroy': ['plant_a_tree']}
    config_content = ansible_config(provider, playbooks)

    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    args.append('-d')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks['destroy'])
    calls = []
    for playbook in playbook_list:
        cmd = [ANSIBLEPB_EXE, '-i', inventory, playbook]
        calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_e_reg(run, _, base_args, tmpdir, create_inventory, create_playbooks, mock_call_ansibleplaybook):
    """
    Replace email and code before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
    """
    provider = 'grilloparlante'
    config_content = """---
apiver: 2
provider: grilloparlante
ansible:
    hana_urls: somesome
    create:
        - registration.yaml -e reg_code=${reg_code} -e email_address=${email}
    variables:
        reg_code: 1234-5678-90XX
        email: mastro.geppetto@collodi.it
    """
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['registration'])
    calls = []
    cmd = [
        ANSIBLEPB_EXE,
        '-i', inventory,
        playbook_list[0],
        '-e', 'reg_code=1234-5678-90XX',
        '-e', 'email_address=mastro.geppetto@collodi.it'
    ]
    calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_e_sapconf(run, _, base_args, tmpdir, create_inventory, create_playbooks, mock_call_ansibleplaybook):
    """
    Replace sapconf flag before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
    """
    provider = 'grilloparlante'
    config_content = """---
apiver: 2
provider: grilloparlante
ansible:
    hana_urls: somesome
    create:
        - sap-hana-preconfigure.yaml -e "use_sapconf=${sapconf}"
    variables:
        sapconf: True
    """
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(['sap-hana-preconfigure'])
    calls = []
    cmd = [
        ANSIBLEPB_EXE,
        '-i', inventory,
        playbook_list[0],
        '-e', '"use_sapconf=True"'
    ]
    calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_ssh(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config, mock_call_ansibleplaybook):
    """
    This first Ansible command has to be called before all the others

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

    # Accept new ssh keys for ansible-controlled hosts
    ansible ${AnsFlgs} all -a true --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks['create'])
    calls = []
    ssh_share = [ANSIBLE_EXE, '-i', inventory, 'all', '-a', 'true', '--ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"']
    calls.append(mock.call(cmd=ssh_share))
    for playbook in playbook_list:
        cmd = [ANSIBLEPB_EXE, '-i', inventory, playbook]
        calls.append(mock_call_ansibleplaybook(cmd))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_env_config(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config):
    """
    Test that ANSIBLE_PIPELINING is added to the env used to run Ansible. In the build.sh it was:

if [ ${quite} -eq 1 ]
then
  export ANSIBLE_NOCOLOR=True
  export ANSIBLE_LOG_PATH="$(pwd)/ansible.build.${LogEx}"
fi
export ANSIBLE_PIPELINING=True
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(playbooks['create'])
    calls = []
    expected_env = dict(os.environ)
    expected_env['ANSIBLE_PIPELINING'] = 'True'
    for playbook in playbook_files_list:
        calls.append(mock.call(cmd=[ANSIBLEPB_EXE, '-i', inventory, playbook], env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_profile(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config):
    """
    Test that --profile result in Ansible called with an additional env variable

        ANSIBLE_CALLBACK_WHITELIST=ansible.posix.profile_tasks
    """
    provider = 'grilloparlante'
    playbooks = {'create': ['get_cherry_wood', 'made_pinocchio_head']}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    args.append('--profile')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(playbooks['create'])
    calls = []
    expected_env = dict(os.environ)
    expected_env['ANSIBLE_PIPELINING'] = 'True'
    expected_env['ANSIBLE_CALLBACK_WHITELIST'] = 'ansible.posix.profile_tasks'
    for playbook in playbook_files_list:
        calls.append(mock.call(cmd=[ANSIBLEPB_EXE, '-i', inventory, playbook], env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch('shutil.which', side_effect=[(ANSIBLEPB_EXE), (ANSIBLE_EXE)])
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_env_roles_path(run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config):
    """
    Test that ANSIBLE_ROLES_PATH is added to the env used to run Ansible.
    It has only to be done if the `roles_path` is present in the Ansible section
    of the config.yaml.
    """
    provider = 'grilloparlante'
    config_content = f"""---
apiver: 2
provider: {provider}
ansible:
    hana_urls: somesome
    roles_path: somewhere
    create:
      - get_cherry_wood.yaml"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append('ansible')
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(['get_cherry_wood'])
    calls = []
    expected_env = dict(os.environ)
    expected_env['ANSIBLE_PIPELINING'] = 'True'
    expected_env['ANSIBLE_ROLES_PATH'] = 'somewhere'
    for playbook in playbook_files_list:
        calls.append(mock.call(cmd=[ANSIBLEPB_EXE, '-i', inventory, playbook], env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)
