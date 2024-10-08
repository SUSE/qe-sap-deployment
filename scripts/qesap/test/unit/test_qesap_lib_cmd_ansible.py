from unittest import mock
import logging
import os
import yaml


from lib.cmds import ansible_export_output, cmd_ansible

log = logging.getLogger(__name__)
FAKE_BIN_PATH = "/paese/della/cuccagna/"


def fake_ansible_path(x):
    return FAKE_BIN_PATH + x


def test_export_ansible_output():
    """
    Utility function that get the ansible command line and the command output.
    Function calculate the log name by extracting the ansible playbook name from the command line.
    Function take the content of out and write it to a file in the current directory
    """

    test_dir = os.getcwd()
    test_file = os.path.join(test_dir, "ansible.testAll.log.txt")

    command_to_sent = [
        "/tmp/exec_venv/bin/ansible-playbok",
        "-vvvv",
        "-i",
        "/root/qe-sap-deployment/terraform/aws/inventory.yaml",
        "/some/immaginary/path/ansible/playbooks/testAll.yaml",
        "-e",
        "something=somevalue",
    ]
    ansible_output = """whatever multiline string
    produced by Ansible"""

    ansible_export_output(command_to_sent, ansible_output)

    assert os.path.isfile(
        test_file
    ), f"Ansible output file {test_file} was not created."
    os.remove(test_file)


@mock.patch("shutil.which", side_effect=lambda x: fake_ansible_path(x))
@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_ansible(
    subprocess_run,
    _,
    tmpdir,
    create_playbooks,
    create_inventory,
    ansible_exe_call,
    mock_call_ansibleplaybook,
):
    """
    This test coverage overlap with tests from
    scripts/qesap/test/unit/test_qesap_ansible.py

    This one is calling lower API (like `cmd_ansible`)
    than the other (that is using `main('ansible')`)

    For this reason, in this file, there's only one single test
    about cmd_ansible.

    All other cmd_ansible functionality are tested in test_qesap_ansible.py
    """

    # Set env and input
    conf_yaml = """---
apiver: 3
provider: "lolo"
ansible:
  hana_media: ciao
  az_storage_account_name: bau
  az_container_name: fao
  az_sas_token: maoooo
  create:
    - babo.yaml
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    playbook = create_playbooks(["babo"])
    inventory = create_inventory("lolo")

    subprocess_run.return_value = (
        0,
        ["This is the ansible output", "Two lines of that"],
    )

    # Set expectation
    calls = []
    calls.append(mock.call(cmd=ansible_exe_call(inventory)))
    calls.append(mock_call_ansibleplaybook(inventory, playbook[0]))

    ret = cmd_ansible(data, tmpdir, False, False)

    assert ret == 0

    subprocess_run.assert_has_calls(calls)
