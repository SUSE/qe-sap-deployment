import logging
import os


from lib.cmds import export_ansible_output

log = logging.getLogger(__name__)


def test_export_ansible_output():
    """
    Utility function that get the ansible command line and the command output.
    Function calculate the log name by extracting the ansible playbook name from the command line.
    Function take the content of out and write it to a file in the current directory
    """

    test_dir = os.getcwd()
    test_file = os.path.join(test_dir, "ansible.testAll.log.txt")
    command_to_sent = {
        "test1": "test_value1",
        "test2": "test_value2",
        "test3": "test_value3",
        "test4": "test_value4",
        "cmd": [
            "/tmp/exec_venv/bin/ansible",
            "-vvvv",
            "-i",
            "/root/qe-sap-deployment/terraform/aws/inventory.yaml",
            "/some/immaginary/path/testAll.yaml",
            "-a",
            '--ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"',
        ],
    }
    ansible_output = """DEBUG    OUTPUT: ansible [core 2.13.5]
                        DEBUG    OUTPUT:   config file = None
                        DEBUG    OUTPUT:   configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
                        DEBUG    OUTPUT:   ansible python module location = /tmp/exec_venv/lib64/python3.11/site-packages/ansible
                        DEBUG    OUTPUT:   ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
                        DEBUG    OUTPUT:   executable location = /tmp/exec_venv/bin/ansible
                        DEBUG    OUTPUT:   python version = 3.11.5 (main, Sep 06 2023, 11:21:05) [GCC]
                        DEBUG    OUTPUT:   jinja version = 3.1.4
                        DEBUG    OUTPUT:   libyaml = True"""

    export_ansible_output(command_to_sent, ansible_output)

    assert os.path.isfile(test_file), f"Ansible output file {test_file} was not created."
    os.remove(test_file)
