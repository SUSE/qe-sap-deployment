"""
sub commands library
"""

import os
import shutil
import re
import logging
import yaml

from lib.config import CONF
import lib.process_manager
from lib.status import Status

log = logging.getLogger("QESAP")


def create_tfvars(config, template):
    """Create the tfvars file content

    Args:
        config (obj): CONF instance
        template (str): tfvars template, full path

    Returns:
        tfvar_content (dict): dictionary with tfvars content. None in case of error
        err (str): Error message, None in case of PASS
    """
    if template:
        log.debug("tfvar template %s", template)
        tfvar_content = config.template_to_tfvars(template)
        return tfvar_content, None
    if config.terraform_yml():
        log.debug("tfvar template not present")
        tfvar_content = config.yaml_to_tfvars()
        if tfvar_content is None:
            log.error("Empty tfvar_content")
            return None, "Problem converting config.yaml content to terraform.tfvars"
        return tfvar_content, None
    return None, "No terraform.tfvars.template neither terraform in the configuration"


def create_hana_media(config_ansible, apiver):
    """Create the hana_media file content

    Args:
        apiver (int): value from apiver
        config_ansible (dict): dictionary that rappresent the conf.yaml ansible section

    Returns:
        hanamedia_content (dict): dictionary with hana_media content. None in case of error
        err (str): Error message, None in case of PASS
    """
    hanamedia_content = {}
    if apiver < 3:
        log.error("Apiver:%d is no longer supported", apiver)
        return None, f"Problems in apiver: {apiver} data conversion"
    hanamedia_content["az_storage_account_name"] = config_ansible[
        "az_storage_account_name"
    ]
    hanamedia_content["az_container_name"] = config_ansible["az_container_name"]
    if "az_sas_token" in config_ansible:
        hanamedia_content["az_sas_token"] = config_ansible["az_sas_token"]
    if "az_key_name" in config_ansible:
        hanamedia_content["az_key_name"] = config_ansible["az_key_name"]
    hanamedia_content["az_blobs"] = config_ansible["hana_media"]
    return hanamedia_content, None


def cmd_configure(configure_data, base_project, dryrun):
    """Main executor for the configure sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the terraform and ansible folder
                      to write all the needed files
        dryrun (bool): enable dryrun execution mode.
                       Does not write any file.

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """

    # Validations
    config = CONF(configure_data)
    if not config.validate():
        return Status(f"Invalid configuration file content in {configure_data}")
    cfg_paths = config.validate_basedir(base_project)
    if not cfg_paths:
        return Status(f"Invalid folder structure at {base_project}")

    template = config.has_tfvar_template()
    tfvar_content, err = create_tfvars(config, template if template else None)
    if err is not None:
        return Status(err)

    if not config.validate_ansible_config(None):
        return Status("Problems in the ansible part of the configuration")

    if config.has_ansible():
        hanamedia_content, err = create_hana_media(
            configure_data["ansible"], configure_data["apiver"]
        )
        if err is not None:
            return Status(err)
        log.debug("Hana media %s:\n%s", cfg_paths["hana_media_file"], hanamedia_content)

    if dryrun:
        print(f"Create {cfg_paths['tfvars_file']} with content {tfvar_content}")
        if config.has_ansible():
            print(
                f"Create {cfg_paths['hana_media_file']} with content {hanamedia_content}"
            )
            if (
                "hana_vars" in configure_data["ansible"]
                and configure_data["apiver"] >= 2
            ):
                print(
                    f"Create {cfg_paths['hana_vars_file']} with content {configure_data['ansible']['hana_vars']}"
                )
    else:
        log.info("Write .tfvars %s", cfg_paths["tfvars_file"])
        with open(cfg_paths["tfvars_file"], "w", encoding="utf-8") as file:
            file.write("".join(tfvar_content))
            file.write("\n")

        if config.has_ansible():
            log.info("Write hana_media %s", cfg_paths["hana_media_file"])
            with open(cfg_paths["hana_media_file"], "w", encoding="utf-8") as file:
                yaml.dump(hanamedia_content, file)

            if (
                "hana_vars" in configure_data["ansible"]
                and configure_data["apiver"] >= 2
            ):
                log.info("Write hana_vars %s", cfg_paths["hana_vars_file"])
                with open(cfg_paths["hana_vars_file"], "w", encoding="utf-8") as file:
                    yaml.dump(configure_data["ansible"]["hana_vars"], file)
    return Status("ok")


def cmd_deploy(configure_data, base_project, dryrun=False, verbose=False):
    """Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Terraform and Ansible files
        dryrun (bool): enable dryrun execution mode
        verbose (bool): enable more verbosity

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    res = cmd_configure(configure_data, base_project, dryrun)
    if res != 0:
        return res
    res = cmd_terraform(
        configure_data, base_project, dryrun, workspace="default", destroy=False
    )
    if res != 0:
        return res
    return cmd_ansible(configure_data, base_project, dryrun, verbose, destroy=False)


def cmd_destroy(configure_data, base_project, dryrun=False, verbose=False):
    """Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Terraform and Ansible files
        dryrun (bool): enable dryrun execution mode
        verbose (bool): enable more verbosity

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    config = CONF(configure_data)
    if not config.validate():
        return Status(f"Invalid configuration file content in {configure_data}")
    res = cmd_ansible(configure_data, base_project, dryrun, verbose, destroy=True)
    if res != 0:
        return res
    return cmd_terraform(
        configure_data, base_project, dryrun, workspace="default", destroy=True
    )


def cmd_terraform(
    configure_data,
    base_project,
    dryrun,
    workspace="default",
    destroy=False,
    parallel=None,
):
    """Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Terraform files
        dryrun (bool): enable dryrun execution mode
        workspace (str): name of the workspace to activate before running the deployment
        destroy (bool): destroy
        parallel (int): value to use for argument --parallelism=n when call terraform plan and apply

    Returns:
        Status: execution result, 0 means OK. It is mind to be used as script exit code
    """

    # Validations
    config = CONF(configure_data)
    if not config.validate():
        return Status(f"Invalid configuration file content in {configure_data}")
    cfg_paths = config.validate_basedir(base_project)
    if not cfg_paths:
        return Status(f"Invalid folder structure at {base_project}")

    terraform_common_cmd = (
        f"{config.get_terraform_bin()} -chdir={cfg_paths['provider']}"
    )

    cmds = []
    if destroy:
        cmds.append(f"{terraform_common_cmd} destroy -auto-approve")
        if workspace != "default":
            cmds.append(f"{terraform_common_cmd} workspace select default")
            cmds.append(f"{terraform_common_cmd} workspace delete {workspace}")
    else:
        cmds.append(f"{terraform_common_cmd} init")
        if workspace != "default":
            cmds.append(f"{terraform_common_cmd} workspace new {workspace}")
        parallel_str = ""
        if parallel:
            parallel_str = f"-parallelism={parallel} "
        cmds.append(f"{terraform_common_cmd} plan {parallel_str}-out=plan.zip")
        cmds.append(
            f"{terraform_common_cmd} apply {parallel_str}-auto-approve plan.zip"
        )

    for command in cmds:
        command += " -no-color"
        if dryrun:
            print(command)
        else:
            ret, out = lib.process_manager.subprocess_run(command)
            log.debug("Terraform process return ret:%d", ret)
            log_filename = f"terraform.{command.split()[2]}.log.txt"
            log.debug("Write %s getcwd:%s", log_filename, os.getcwd())
            with open(log_filename, "w", encoding="utf-8") as log_file:
                log_file.write("\n".join(out))
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(f"Error rc: {ret} at {command}")
    return Status("ok")


def ansible_validate(config, base_project, sequence, provider):
    """
    Validate all elements needed to execute the Ansible sequence.
    Part of that is about the Ansible part of conf.yaml
    Part of that is about files generated at runtime from previous steps (like Terraform)
    """
    if not config.has_ansible():
        return False, "Deployment configured without Ansible."
    if not config.validate():
        return False, "Invalid configuration file content."

    if config.has_ansible_playbooks(sequence):
        if not config.validate_ansible_config(sequence):
            return (
                False,
                "Invalid internal structure of the Ansible part of config.yaml",
            )
        for playbook in config.get_playbooks(sequence):
            playbook_filename = os.path.join(
                base_project, "ansible", "playbooks", playbook.split(" ")[0]
            )
            if not os.path.isfile(playbook_filename):
                log.error("Missing playbook at %s", playbook_filename)
                return False, f"Missing playbook: {playbook_filename}"
    inventory = os.path.join(base_project, "terraform", provider, "inventory.yaml")
    if not os.path.isfile(inventory):
        log.error("Missing inventory at %s", inventory)
        return False, "Missing inventory"
    return True, ""


def ansible_command_sequence(
    configure_data_ansible, base_project, sequence, verbose, inventory, profile, junit, apiver
):
    """Compose the sequence of Ansible commands

    Args:
        configure_data_ansible (obj): ansible part of the configure_data
        base_project (str): base project path where to
                      look for the Ansible files
        sequence (str): 'create' or 'destroy'
        verbose (bool): enable more verbosity
        inventory (str): inventory.yaml file path
        profile (bool): enable task profile
        junit (str): enable junit report and provide folder where to store report
        apiver (int): apiver of the conf.yaml. It is important to know if apiver >= 4,
                      that means list of playbooks is within the new key sequences

    Returns:
        list of strings, each of them is an anslble or ansible-playbook command
    """

    # 1. Create the environment variable set
    #    that will be used by any command
    original_env = dict(os.environ)
    original_env["ANSIBLE_PIPELINING"] = "True"
    original_env["ANSIBLE_TIMEOUT"] = "20"
    ansible_callbacks = []
    if profile:
        ansible_callbacks.append("ansible.posix.profile_tasks")
    if junit:
        ansible_callbacks.append("junit")
        original_env["JUNIT_OUTPUT_DIR"] = junit
    if len(ansible_callbacks) > 0:
        original_env["ANSIBLE_CALLBACKS_ENABLED"] = ",".join(ansible_callbacks)
    if "roles_path" in configure_data_ansible:
        original_env["ANSIBLE_ROLES_PATH"] = configure_data_ansible["roles_path"]

    # 2. Verify that the two needed binaries are usable
    ansible_bin_paths = {}
    for ansible_bin in ["ansible", "ansible-playbook"]:
        binpath = shutil.which(ansible_bin)
        if not binpath:
            log.error("Missing binary %s", ansible_bin)
            return False, f"Missing binary {ansible_bin}"
        ansible_bin_paths[ansible_bin] = binpath

    # 3. Compose common parts of all ansible commands
    #    so the set of generic arguments that apply both
    #    to ansible and ansible-playbook
    ansible_common = "-vv"
    if verbose:
        # add two more 'v' without any space
        ansible_common += "vv"
    ansible_common += f" -i {inventory}"

    # 4. Start composing and accumulating all needed commands in a list
    ansible_cmd_seq = []

    if junit and not os.path.isdir(junit):
        # This is the folder also used in the Ansible configuration JUNIT_OUTPUT_DIR.
        # ansible-playbook is able to create it from its own but
        # is a failure occur in the first sequence command, that is ansible and not ansible-playbook,
        # the folder is not created.
        # Create an empty folder in advance, if it is not already there
        # so that the glue script called can always suppose that at least the folder is present.
        ansible_cmd_seq.append({"cmd": f"mkdir -p {junit}"})

    # This is to avoid any manual intervention during first connection.
    # Without this code it is usually needed to interactively
    # accept the ssh host fingerprint.
    # It is implemented using https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html
    #  - the binary used is 'ansible' instead of 'ansible-playbook'
    #  - option 'all' runs the same command on all hosts in the inventory (that comes from ansible_common)
    #  - '-a' is for running a single command remotely,
    #  - 'true' is just the simplest possible command as the point is not what we run but establishing a first connection
    # to have the fingerprint saved in the local known_host file.
    ssh_share = f"{ansible_bin_paths['ansible']} {ansible_common} all -a true"
    # Don't set '--ssh-extra-args="..."' but 'ssh-extra-args=...'
    # for avoiding the ansible ssh connection failure introduced by
    # https://github.com/ansible/ansible/pull/78826 in "ansible-core 2.15.0"
    ssh_share += ' --ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"'
    ansible_cmd_seq.append({"cmd": ssh_share})

    selected_list_of_playbooks = []
    if apiver < 4:
        selected_list_of_playbooks = configure_data_ansible[sequence]
    else:
        selected_list_of_playbooks = configure_data_ansible["sequences"][sequence]
    for playbook in selected_list_of_playbooks:
        # playbook input is here from the conf.yaml
        # 1. it could be a string only with one playbook file name, no path
        # 2. it could have some arguments, so single string with arguments separated by spaces
        # 3. it could have variables to be resolved (variables are a custom internal string replacement concept)
        #
        # Before to run compose the command line, apply some normalization:
        # 1. the path of the playbook is converted to absolute path.
        #    The existence of the playbook file has been already checked during the configure stage
        # 2. any variable is substituted with its value
        log.debug("playbook:%s", playbook)

        # get the file named in the conf.yaml from playbook_cmd
        # and append the full path within the repo folder
        playbook_filename = playbook.split()[0]
        playbook_abs_filename = os.path.join(
            base_project, "ansible", "playbooks", playbook_filename
        )
        playbook = re.sub(playbook_filename, playbook_abs_filename, playbook)

        # look for variable in the form of `${SOMENAME}`
        for match in re.findall(r"\${[A-Za-z0-9_\-]+}", playbook):
            # 2 and -1 are to remove ${ and }
            value = str(configure_data_ansible["variables"][match[2:-1]])
            log.debug("Replace value %s in %s", value, playbook)
            playbook = re.sub(rf"\${{{match[2:-1]}}}", value, playbook)

        # Finally compose the command ansible-playbook using the resolved `playbook` string
        ansible_cmd_seq.append(
            {
                "cmd": f"{ansible_bin_paths['ansible-playbook']} {ansible_common} {playbook}",
                "env": original_env,
            }
        )
    return True, ansible_cmd_seq


def execute_ansible_commands(commands, dryrun):
    """Helper to execute a list of ansible commands.

    Args:
        commands (list): List of command dictionaries as prepared by ansible_command_sequence.
        dryrun (bool): Enable dryrun execution mode.

    Returns:
        Status: Execution result, 0 means OK.
    """
    for command in commands:
        if dryrun:
            print(command["cmd"])
        else:
            ret, out = lib.process_manager.subprocess_run(**command)
            log.debug("Ansible process return ret:%d", ret)
            if "ansible-playbook" in command["cmd"]:
                ansible_export_output(command["cmd"], out)
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(f"Error rc: {ret} at {command}")
    return Status("ok")


def ansible_export_output(command, out):
    """Write the Ansible (or ansible-playbook) stdout to file

    Function is in charge to:
    - get a cmd and calculate from it the log file name to write.
      The filename is calculated, when available, from the playbook name: stripping '.yaml' and adding '.log.txt'
    - open a file in write mode. Path for this file is the current directory
    - write to the file the content of the out variable. Each element of the out list to a new file line

    Args:
        command (str): one cmd element as prepared by ansible_command_sequence
        out (str list): as returned by subprocess_run
    """
    # log name has to be derived from the name of the playbook:
    # search the playbook name in all command words.
    playbook_path = None
    for cmd_element in command.split():
        match = re.search(rf"{os.path.join('ansible', 'playbooks')}.*", cmd_element)
        if match:
            playbook_path = cmd_element
            break
    if playbook_path is None:
        log.error("Unable to find which one is the playbook in %s", command)
        return
    playbook_name = os.path.splitext(os.path.basename(playbook_path))[0]
    log_filename = f"ansible.{playbook_name}.log.txt"
    log.debug("Write %s getcwd:%s", log_filename, os.getcwd())
    with open(log_filename, "w", encoding="utf-8") as log_file:
        log_file.write("\n".join(out))


def cmd_ansible(
    configure_data,
    base_project,
    dryrun,
    verbose,
    destroy=False,
    profile=False,
    junit=False,
    sequence=None,
):
    """Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode
        verbose (bool): enable more verbosity
        destroy (bool): select the playbook list
        profile (bool): enable task profile
        junit (str): enable junit report and provide folder where to store it
        sequence (str): only run a named section from the ansible::sequence conf.yaml part.
                       In case it is used with conf.yaml using apiver <4, only 'create' and 'destroy'
                       values are supported.

    Returns:
        Status: execution result, 0 means OK. It is mind to be used as script exit code
    """
    if sequence:
        if (configure_data["apiver"] >= 4) or (sequence in ["create", "destroy"]):
            selected_sequence = sequence
        else:
            err = f"Required section '{sequence}' is not supported by conf.yaml with apiver:{configure_data['apiver']}"
            log.error(err)
            return Status(err)
    else:
        selected_sequence = "create"
        if destroy:
            selected_sequence = "destroy"

    # Validations
    config = CONF(configure_data)
    if not config.has_ansible():
        err = f"Deployment configured without Ansible in {configure_data}"
        log.error(err)
        return Status(err)

    res, msg = ansible_validate(
        config, base_project, selected_sequence, configure_data["provider"]
    )
    if not res:
        log.error(msg)
        return Status(msg)

    if not config.has_ansible_playbooks(selected_sequence):
        log.info("No playbooks to play")
        return Status("ok")

    inventory = os.path.join(
        base_project, "terraform", configure_data["provider"], "inventory.yaml"
    )
    ret, ansible_cmd_seq = ansible_command_sequence(
        configure_data["ansible"],
        base_project,
        selected_sequence,
        verbose,
        inventory,
        profile,
        junit,
        configure_data["apiver"]
    )
    if not ret:
        log.error("ansible_command_sequence ret:%d", ret)
        return Status(ansible_cmd_seq)

    return execute_ansible_commands(ansible_cmd_seq, dryrun)
