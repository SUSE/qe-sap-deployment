import os
from unittest import mock
import logging

from qesap import main


log = logging.getLogger(__name__)


def fake_ansible_path(x):
    return "/paese/della/cuccagna/" + x


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_create(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Test that the ansible subcommand plays playbooks
    listed in the ansible::create part of the config.yml
    """
    provider = "grilloparlante"

    # Start by defining a dictionary with a set of playbooks
    # this is a dictionary format that is only useful in this test content
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}

    # list of playbooks is written in the conf.yaml
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    # the list of playbooks is used to create files on the disk, that qesap.py
    # will verify to be present and use as composing each ansible-playbooks cmd line
    playbook_files_list = create_playbooks(playbooks["create"])
    inventory = create_inventory(provider)

    # define what the simulated subprocess_run has to return
    run.return_value = (0, [])

    # create the list of arguments to call qesap.py
    args = base_args(None, config_file_name, False)
    args.append("ansible")

    # Call the glue script: run the test
    assert main(args) == 0

    # define expectations in term of expected list of
    # ansible-playbooks command that we expect to be executed based on the
    # list of playbooks specified in the conf.yaml
    calls = []
    for playbook in playbook_files_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook))

    # Check Actual behavior against the expectation
    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_verbose(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    run with -vvvv if qesap ansible --verbose
    (probably not supported in qesap deploy/destroy)
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood"]}

    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)
    playbook_list = create_playbooks(playbooks["create"])
    calls = []
    for playbook in playbook_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook, verbosity="-vvvv"))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_dryrun(
    run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config
):
    """
    Command ansible does not call the Ansible executable in dryrun mode
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}

    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append("ansible")
    args.insert(0, "--dryrun")
    run.return_value = (0, [])
    create_inventory(provider)
    create_playbooks(playbooks["create"])

    assert main(args) == 0

    run.assert_not_called()


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_no_ansible(run, _, base_args, tmpdir):
    """
    Test behavior for a conf.yaml without the `ansible:` section

    If the user create a config.yaml without the ansible: section
    the `qesap.py ... ansible` command invocation has to fail.
    """
    config_content = """---
apiver: 3
provider: grilloparlante"""
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, True)
    args.append("ansible")
    run.return_value = (0, [])

    assert main(args) == 1

    run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_missing_inventory(
    run, tmpdir, base_args, create_playbooks, ansible_config
):
    """
    Stop and return non zero if inventory is missing
    """
    config_content = ansible_config("grilloparlante", {"create": ["get_cherry_wood"]})
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    # create the playbook written in the conf.yaml
    # otherwise the cmd_ansible fails for missing playbook and not
    # for missing inventory: test is PASS
    # but not testing what is intended for.
    create_playbooks(["get_cherry_wood"])

    args = base_args(None, config_file_name, False)
    args.append("ansible")

    assert main(args) != 0

    run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_no_playbooks(run, tmpdir, base_args, create_inventory, ansible_config):
    """
    If no playbooks are listed, Ansible is not called
    """
    provider = "grilloparlante"

    config_content = ansible_config(provider, {})
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    create_inventory(provider)

    assert main(args) == 0

    run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_missing_playbook(
    run, tmpdir, base_args, create_inventory, create_playbooks, ansible_config
):
    """
    ansible subcommand has not to run any commands if
    any of the playbooks YAML file referred in the config.yaml
    does not exist
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)

    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    create_inventory(provider)
    # create one out of two
    create_playbooks(playbooks["create"][0:1])

    assert main(args) != 0

    run.assert_not_called()


@mock.patch("shutil.which", side_effect=lambda x: None)
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_no_bin(
    run, _, tmpdir, base_args, create_inventory, create_playbooks, ansible_config
):
    """
    Simulate script executed in an environment
    where neither Ansible or ansible-playbook are installed.

    This situation is obtained configuring None in
    `side_effect=lambda x: None`

    It is like to say that the tested function will not find any binary for
    both ansible and ansible-playbook.
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")

    # Create the inventory and the playbook file
    # is needed to avoid the tested function to fails
    # due to the absence of them.
    # This test does not want it: this test has to get
    # a failure due to the lack of binary.
    create_inventory(provider)
    create_playbooks(playbooks["create"])

    assert main(args) != 0

    run.assert_not_called()


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run", side_effect=[(0, []), (1, [])])
def test_ansible_stop(
    run,
    _,
    tmpdir,
    base_args,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Stop the sequence of playbook at first one
    that is failing and return non zero
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks["create"])
    calls = []
    calls.append(mock_call_ansibleplaybook(inventory, playbook_list[0]))

    assert main(args) != 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_destroy(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Test that ansible subcommand, called with -d,
    call the destroy list of playbooks
    """
    provider = "grilloparlante"
    playbooks = {
        "create": ["get_cherry_wood", "made_pinocchio_head"],
        "destroy": ["plant_a_tree"],
    }
    config_content = ansible_config(provider, playbooks)

    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    args.append("-d")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks["destroy"])
    calls = []
    for playbook in playbook_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_playbook_argument(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    mock_call_ansibleplaybook,
):
    """
    Check that any generic `-e` argument is used on the command line
    """
    provider = "grilloparlante"
    config_content = """---
apiver: 3
provider: grilloparlante
ansible:
    az_storage_account_name: pippo
    az_container_name: pippo
    az_sas_token: SECRET
    hana_media:
    - somesome
    create:
        - baboom.yaml -e pim=pam
    """
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(["baboom"])
    calls = []
    calls.append(
        mock_call_ansibleplaybook(
            inventory, playbook_list[0], arguments=["-e", "pim=pam"]
        )
    )

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_e_reg(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    mock_call_ansibleplaybook,
):
    """
    Replace email and code before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/registration.yaml -e "reg_code=${REG_CODE}" -e "email_address=${EMAIL}"
    """
    provider = "grilloparlante"
    config_content = """---
apiver: 3
provider: grilloparlante
ansible:
    az_storage_account_name: pippo
    az_container_name: pippo
    az_sas_token: SECRET
    hana_media:
    - somesome
    create:
        - registration.yaml -e reg_code=${reg_code} -e email_address=${email}
    variables:
        reg_code: 1234-5678-90XX
        email: mastro.geppetto@collodi.it
    """
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(["registration"])
    calls = []
    ap_args = [
        "-e",
        "reg_code=1234-5678-90XX",
        "-e",
        "email_address=mastro.geppetto@collodi.it",
    ]
    calls.append(
        mock_call_ansibleplaybook(inventory, playbook_list[0], arguments=ap_args)
    )

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_e_sapconf(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    mock_call_ansibleplaybook,
):
    """
    Replace sapconf flag before to run
    ansible-playbook ${AnsFlgs} ${AnsPlybkPath}/sap-hana-preconfigure.yaml -e "use_sapconf=${SAPCONF}"
    """
    provider = "grilloparlante"
    config_content = """---
apiver: 3
provider: grilloparlante
ansible:
    az_storage_account_name: pippo
    az_container_name: pippo
    az_sas_token: SECRET
    hana_media:
    - somesome
    create:
    - sap-hana-preconfigure.yaml -e "use_sapconf=${sapconf}"
    variables:
        sapconf: True
    """
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(["sap-hana-preconfigure"])
    calls = []
    ap_args = ["-e", '"use_sapconf=True"']
    calls.append(
        mock_call_ansibleplaybook(inventory, playbook_list[0], arguments=ap_args)
    )

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_ssh(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
    ansible_exe_call,
):
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
    ansible ${AnsFlgs} all -a true --ssh-extra-args=-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_list = create_playbooks(playbooks["create"])
    calls = []

    calls.append(mock.call(cmd=ansible_exe_call(inventory)))
    for playbook in playbook_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch.dict(os.environ, {"MELAMPO": "cane"}, clear=True)
@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_env_config(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Test that ANSIBLE_PIPELINING is added to the env used to run Ansible.
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(playbooks["create"])
    calls = []
    # considering internally mock_call_ansibleplaybook is doing exactly the same
    # this part is already covered in all other test.
    # Keep it here just to be more explicit and due to the fact that here
    # the os.environ is mock.
    expected_env = {"MELAMPO": "cane"}
    expected_env["ANSIBLE_PIPELINING"] = "True"
    for playbook in playbook_files_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook, env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch.dict(os.environ, {"MELAMPO": "cane"}, clear=True)
@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_profile(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Test that --profile result in Ansible called with an additional env variable

        ANSIBLE_CALLBACKS_ENABLED=ansible.posix.profile_tasks
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    args.append("--profile")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(playbooks["create"])
    calls = []
    expected_env = {"MELAMPO": "cane"}
    expected_env["ANSIBLE_PIPELINING"] = "True"
    expected_env["ANSIBLE_CALLBACKS_ENABLED"] = "ansible.posix.profile_tasks"
    for playbook in playbook_files_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook, env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch.dict(os.environ, {"MELAMPO": "cane"}, clear=True)
@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_junit(
    run,
    s,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Test that using '--junit' on the glue script command line
    results in two additional env variables added at each ansible command execution

        ANSIBLE_CALLBACKS_ENABLED=junit
        JUNIT_OUTPUT_DIR="/something/somewhere"
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}
    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    args.append("--junit")
    args.append("/something/somewhere")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(playbooks["create"])
    calls = []
    expected_env = {"MELAMPO": "cane"}
    expected_env["ANSIBLE_PIPELINING"] = "True"
    expected_env["ANSIBLE_CALLBACKS_ENABLED"] = "junit"
    expected_env["JUNIT_OUTPUT_DIR"] = "/something/somewhere"
    for playbook in playbook_files_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook, env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_env_roles_path(
    run,
    _,
    base_args,
    tmpdir,
    create_inventory,
    create_playbooks,
    ansible_config,
    mock_call_ansibleplaybook,
):
    """
    Test that ANSIBLE_ROLES_PATH is added to the env used to run Ansible.
    It has only to be done if the `roles_path` is present in the Ansible section
    of the config.yaml.
    """
    provider = "grilloparlante"
    config_content = f"""---
apiver: 3
provider: {provider}
ansible:
    az_storage_account_name: pippo
    az_container_name: pippo
    az_sas_token: SECRET
    hana_media:
    - somesome
    roles_path: somewhere
    create:
      - get_cherry_wood.yaml"""
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    args = base_args(None, config_file_name, False)
    args.append("ansible")
    run.return_value = (0, [])

    inventory = create_inventory(provider)

    playbook_files_list = create_playbooks(["get_cherry_wood"])
    calls = []
    expected_env = dict(os.environ)
    expected_env["ANSIBLE_PIPELINING"] = "True"
    expected_env["ANSIBLE_ROLES_PATH"] = "somewhere"
    for playbook in playbook_files_list:
        calls.append(mock_call_ansibleplaybook(inventory, playbook, env=expected_env))

    assert main(args) == 0

    run.assert_called()
    run.assert_has_calls(calls)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_ansible_create_logs(
    run, _, base_args, tmpdir, create_inventory, create_playbooks, ansible_config
):
    """
    Test that config.yml with playbook named `<SOMETHING>.yaml`
    result in the generation of a log file named `<SOMETHING>.log.txt`
    """
    provider = "grilloparlante"
    playbooks = {"create": ["get_cherry_wood", "made_pinocchio_head"]}

    config_content = ansible_config(provider, playbooks)
    config_file_name = str(tmpdir / "config.yaml")
    with open(config_file_name, "w", encoding="utf-8") as file:
        file.write(config_content)

    create_playbooks(playbooks["create"])
    create_inventory(provider)

    run.return_value = (0, [])

    args = base_args(None, config_file_name, False)
    args.append("ansible")

    assert main(args) == 0

    assert os.path.isfile("ansible.get_cherry_wood.log.txt")
    assert os.path.isfile("ansible.made_pinocchio_head.log.txt")
