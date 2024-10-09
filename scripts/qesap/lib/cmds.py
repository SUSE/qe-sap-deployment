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

log = logging.getLogger('QESAP')


def create_tfvars(config, template):
    """ Create the tfvars file content

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
    """ Create the hana_media file content

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
    hanamedia_content['az_storage_account_name'] = config_ansible['az_storage_account_name']
    hanamedia_content['az_container_name'] = config_ansible['az_container_name']
    if 'az_sas_token' in config_ansible:
        hanamedia_content['az_sas_token'] = config_ansible['az_sas_token']
    if 'az_key_name' in config_ansible:
        hanamedia_content['az_key_name'] = config_ansible['az_key_name']
    hanamedia_content['az_blobs'] = config_ansible['hana_media']
    return hanamedia_content, None


def cmd_configure(configure_data, base_project, dryrun):
    """ Main executor for the configure sub-command

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
        hanamedia_content, err = create_hana_media(configure_data['ansible'], configure_data['apiver'])
        if err is not None:
            return Status(err)
        log.debug("Hana media %s:\n%s", cfg_paths['hana_media_file'], hanamedia_content)

    if dryrun:
        print(f"Create {cfg_paths['tfvars_file']} with content {tfvar_content}")
        print(f"Create {cfg_paths['hana_media_file']} with content {hanamedia_content}")
    else:
        log.info("Write .tfvars %s", cfg_paths['tfvars_file'])
        with open(cfg_paths['tfvars_file'], 'w', encoding='utf-8') as file:
            file.write(''.join(tfvar_content))

        if config.has_ansible():
            log.info("Write hana_media %s", cfg_paths['hana_media_file'])
            with open(cfg_paths['hana_media_file'], 'w', encoding='utf-8') as file:
                yaml.dump(hanamedia_content, file)

            if 'hana_vars' in configure_data['ansible'] and configure_data['apiver'] >= 2:
                log.info("Write hana_vars %s", cfg_paths['hana_vars_file'])
                with open(cfg_paths['hana_vars_file'], 'w', encoding='utf-8') as file:
                    yaml.dump(configure_data['ansible']['hana_vars'], file)
    return Status('ok')


def cmd_deploy(configure_data, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Terraform and Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return Status('TBD')


def cmd_destroy(configure_data, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Terraform and Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return Status('TBD')


def cmd_terraform(configure_data, base_project, dryrun, workspace='default', destroy=False):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Terraform files
        destroy (bool): destroy
        dryrun (bool): enable dryrun execution mode

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

    cmds = []
    terraform_common_cmd = [config.get_terraform_bin(), f"-chdir={cfg_paths['provider']}"]
    if destroy:
        if workspace != 'default':
            cmds.append(terraform_common_cmd + ['workspace', 'select', 'default', '-no-color'])
            cmds.append(terraform_common_cmd + ['workspace', 'delete', workspace, '-no-color'])
        cmds.append(terraform_common_cmd + ['destroy', '-auto-approve', '-no-color'])
    else:
        cmds.append(terraform_common_cmd + ['init', '-no-color'])
        if workspace != 'default':
            cmds.append(terraform_common_cmd + ['workspace', 'new', workspace, '-no-color'])
        cmds.append(terraform_common_cmd + ['plan', '-out=plan.zip', '-no-color'])
        cmds.append(terraform_common_cmd + ['apply', '-auto-approve', 'plan.zip', '-no-color'])
    for command in cmds:
        if dryrun:
            print(' '.join(command))
        else:
            ret, out = lib.process_manager.subprocess_run(command)
            log.debug("Terraform process return ret:%d", ret)
            log_filename = f"terraform.{command[2]}.log.txt"
            log.debug("Write %s getcwd:%s", log_filename, os.getcwd())
            with open(log_filename, 'w', encoding='utf-8') as log_file:
                log_file.write('\n'.join(out))
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(f"Error rc: {ret} at {command}")
    return Status('ok')


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
            return False, 'Invalid internal structure of the Ansible part of config.yaml'
        for playbook in config.get_playbooks(sequence):
            playbook_filename = os.path.join(base_project, 'ansible', 'playbooks', playbook.split(' ')[0])
            if not os.path.isfile(playbook_filename):
                log.error("Missing playbook at %s", playbook_filename)
                return False, f"Missing playbook: {playbook_filename}"
    inventory = os.path.join(base_project, 'terraform', provider, 'inventory.yaml')
    if not os.path.isfile(inventory):
        log.error("Missing inventory at %s", inventory)
        return False, "Missing inventory"
    return True, ''


def ansible_command_sequence(configure_data_ansible, base_project, sequence, verbose, inventory, profile, junit):
    """ Compose the sequence of Ansible commands

    Args:
        configure_data_ansible (obj): ansible part of the configure_data
        base_project (str): base project path where to
                      look for the Ansible files
        sequence (str): 'create' or 'destroy'
        verbose (bool): enable more verbosity
        inventory (str): inventory.yaml file path
        profile (bool): enable task profile
        junit (str): enable junit report and provide folder where to store report

    Returns:
        list of list of strings, each command is rappresented as a list of its arguments
    """

    # 1. Create the environment variable set
    #    that will be used by any command
    original_env = dict(os.environ)
    original_env['ANSIBLE_PIPELINING'] = 'True'
    ansible_callbacks = []
    if profile:
        ansible_callbacks.append('ansible.posix.profile_tasks')
    if junit:
        ansible_callbacks.append('junit')
        original_env['JUNIT_OUTPUT_DIR'] = junit
    if len(ansible_callbacks) > 0:
        original_env['ANSIBLE_CALLBACKS_ENABLED'] = ','.join(ansible_callbacks)
    if 'roles_path' in configure_data_ansible:
        original_env['ANSIBLE_ROLES_PATH'] = configure_data_ansible['roles_path']

    # 2. Verify that needed binary are usable
    ansible_bin_paths = {}
    for ansible_bin in ['ansible', 'ansible-playbook']:
        binpath = shutil.which(ansible_bin)
        if not binpath:
            log.error("Missing binary %s", ansible_bin)
            return False, f"Missing binary {ansible_bin}"
        ansible_bin_paths[ansible_bin] = binpath

    # 3. Compose common parts of all ansible commands
    ansible_common = [ansible_bin_paths['ansible-playbook']]
    if verbose:
        ansible_common.append('-vvvv')
    else:
        ansible_common.append('-vv')
    ansible_common.append('-i')
    ansible_common.append(inventory)

    # 4. Start composing and accumulating the list of all needed commands
    ansible_cmd = []
    ansible_cmd_seq = []

    if junit and not os.path.isdir(junit):
        # This is the folder also used in the Ansible configuration JUNIT_OUTPUT_DIR.
        # ansible-playbook is able to create it from its own but
        # is a failure occur in the first sequence command, that is ansible and not ansible-playbook,
        # the folder is not created.
        # Create an empty folder in advance, if it is not already there
        # so that the glue script called can always suppose that at least the folder is present.
        ansible_cmd_seq.append({'cmd': ['mkdir', junit]})

    ssh_share = ansible_common.copy()
    ssh_share[0] = ansible_bin_paths['ansible']
    # Don't set '--ssh-extra-args="..."' but 'ssh-extra-args=...'
    # for avoiding the ansible ssh connection failure introduced by
    # https://github.com/ansible/ansible/pull/78826 in "ansible-core 2.15.0"
    ssh_share.extend([
        'all', '-a', 'true',
        '--ssh-extra-args=-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new'])
    ansible_cmd_seq.append({'cmd': ssh_share})

    for playbook in configure_data_ansible[sequence]:
        ansible_cmd = ansible_common.copy()
        playbook_cmd = playbook.split(' ')
        log.debug("playbook:%s", playbook)
        # get the file named in the conf.yaml from playbook_cmd
        # and append the full path within the repo folder
        playbook_filename = os.path.join(base_project, 'ansible', 'playbooks', playbook_cmd[0])
        ansible_cmd.append(playbook_filename)
        for ply_cmd in playbook_cmd[1:]:
            match = re.search(r'\${(.*)}', ply_cmd)
            if match:
                value = str(configure_data_ansible['variables'][match.group(1)])
                log.debug("Replace value %s in %s", value, ply_cmd)
                ansible_cmd.append(re.sub(r'\${(.*)}', value, ply_cmd))
            else:
                ansible_cmd.append(ply_cmd)
        ansible_cmd_seq.append({'cmd': ansible_cmd, 'env': original_env})
    return True, ansible_cmd_seq


def ansible_export_output(command, out):
    """ Write the Ansible (or ansible-playbook) stdout to file

    Function is in charge to:
    - get a cmd and calculate from it the log file name to write.
      The filename is calculated, when available, from the playbook name: stripping '.yaml' and adding '.log.txt'
    - open a file in write mode. Path for this file is the current directory
    - write to the file the content of the out variable. Each element of the out list to a new file line

    Args:
        command (str list): one cmd element as prepared by ansible_command_sequence
        out (str list): as returned by subprocess_run
    """
    # log name has to be derived from the name of the playbook:
    # search the playbook name in all command words.
    playbook_path = None
    for cmd_element in command:
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
    with open(log_filename, 'w', encoding='utf-8') as log_file:
        log_file.write('\n'.join(out))


def cmd_ansible(configure_data, base_project, dryrun, verbose, destroy=False, profile=False, junit=False):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode
        verbose (bool): enable more verbosity
        destroy (bool): select the playbook list
        profile (bool): enable task profile
        profile (str): enable junit report and provide folder where to store it

    Returns:
        Status: execution result, 0 means OK. It is mind to be used as script exit code
    """
    sequence = 'create'
    if destroy:
        sequence = 'destroy'

    # Validations
    config = CONF(configure_data)
    if not config.has_ansible():
        err = f"Deployment configured without Ansible in {configure_data}"
        log.error(err)
        return Status(err)

    res, msg = ansible_validate(config, base_project, sequence, configure_data['provider'])
    if not res:
        log.error(msg)
        return Status(msg)

    if not config.has_ansible_playbooks(sequence):
        log.info("No playbooks to play")
        return Status("ok")

    inventory = os.path.join(base_project, 'terraform', configure_data['provider'], 'inventory.yaml')
    ret, ansible_cmd_seq = ansible_command_sequence(configure_data['ansible'], base_project, sequence, verbose, inventory, profile, junit)
    if not ret:
        log.error("ansible_command_sequence ret:%d", ret)
        return Status(ansible_cmd_seq)

    for command in ansible_cmd_seq:
        if dryrun:
            print(' '.join(command['cmd']))
        else:
            ret, out = lib.process_manager.subprocess_run(**command)
            log.debug("Ansible process return ret:%d", ret)
            # only write separated files for ansible-playbook commands
            if 'ansible-playbook' in command['cmd'][0]:
                ansible_export_output(command['cmd'], out)
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(f"Error rc: {ret} at {command}")
    return Status("ok")
