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
        hana_url_re = r'http.*://(?P<ACCOUNT>.+)\.blob\.core\.windows\.net/(?P<CONTAINER>.+)/(?P<EXE>.+)'
        match = []
        prev_account = None
        prev_container = None
        for this_media in config_ansible['hana_urls']:
            this_match = re.search(hana_url_re, this_media)
            if not this_match:
                log.error("[%s] does not match regexp to extract ACCOUNT, CONTAINER or EXE", this_media)
                return None, f"Problems in apiver:{apiver} data conversion"
            this_account = this_match.group('ACCOUNT')
            this_container = this_match.group('CONTAINER')
            if prev_account is None:
                prev_account = this_account
            elif prev_account != this_account:
                log.error("ACCOUNT [%s] does not match ACCOUNT [%s] used in previous url", this_account, prev_account)
                return None, f"Problems in apiver:{apiver} data conversion"
            if prev_container is None:
                prev_container = this_match.group('CONTAINER')
            elif prev_container != this_container:
                log.error("CONTAINER [%s] does not match CONTAINER [%s] used in previous url", this_container, prev_container)
                return None, f"Problems in apiver:{apiver} data conversion"
            match.append(this_match)

        hanamedia_content['az_storage_account_name'] = match[0].group('ACCOUNT')
        hanamedia_content['az_container_name'] = match[0].group('CONTAINER')
        hanamedia_content['az_blobs'] = []
        for this_match in match:
            hanamedia_content['az_blobs'].append(this_match.group('EXE'))
    else:
        hanamedia_content['az_storage_account_name'] = config_ansible['az_storage_account_name']
        hanamedia_content['az_container_name'] = config_ansible['az_container_name']
        if 'az_sas_token' in config_ansible:
            hanamedia_content['az_sas_token'] = config_ansible['az_sas_token']
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

        if 'hana_vars' in configure_data['ansible'] and configure_data['apiver'] >= 2:
            log.debug("Hana variables %s:\n%s", cfg_paths['hana_vars_file'], configure_data['ansible']['hana_vars'])

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
            log.debug('\n>    '.join(out))
            log.debug("Terraform process return ret:%d", ret)
            log_filename = f"terraform.{command[2]}.log.txt"
            log.debug("Write %s getcwd:%s", log_filename, os.getcwd())
            with open(log_filename, 'w', encoding='utf-8') as log_file:
                log_file.write('\n'.join(out))
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(f"Error at {command}")
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


def ansible_command_sequence(configure_data_ansible, base_project, sequence, verbose, inventory, profile):
    """ Compose the sequence of Ansible commands

    Args:
        configure_data_ansible (obj): ansible part of the configure_data
        base_project (str): base project path where to
                      look for the Ansible files
        sequence (str): 'create' or 'destroy'
        verbose (bool): enable more verbosity
        inventory (str): inventory.yaml file path
        profile (bool): enable task profile

    Returns:
        list of list of strings, each command is rappresented as a list of its arguments
    """

    # if the config.yaml has playbooks, the ansible and ansible-playbooks executables
    # has to be available too
    ansible_bin_paths = {}
    for ansible_bin in ['ansible', 'ansible-playbook']:
        binpath = shutil.which(ansible_bin)
        if not binpath:
            log.error("Missing binary %s", ansible_bin)
            return False, f"Missing binary {ansible_bin}"
        ansible_bin_paths[ansible_bin] = binpath

    ansible_common = [ansible_bin_paths['ansible-playbook']]
    if verbose:
        ansible_common.append('-vvvv')
    else:
        ansible_common.append('-vv')

    ansible_common.append('-i')
    ansible_common.append(inventory)

    ansible_cmd = []
    ansible_cmd_seq = []
    ssh_share = ansible_common.copy()
    ssh_share[0] = ansible_bin_paths['ansible']
    ssh_share.extend([
        'all', '-a', 'true',
        '--ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"'])
    ansible_cmd_seq.append({'cmd': ssh_share})
    original_env = dict(os.environ)
    original_env['ANSIBLE_PIPELINING'] = 'True'
    if profile:
        original_env['ANSIBLE_CALLBACK_WHITELIST'] = 'ansible.posix.profile_tasks'
    if 'roles_path' in configure_data_ansible:
        original_env['ANSIBLE_ROLES_PATH'] = configure_data_ansible['roles_path']

    for playbook in configure_data_ansible[sequence]:
        ansible_cmd = ansible_common.copy()
        playbook_cmd = playbook.split(' ')
        log.debug("playbook:%s", playbook)
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


def cmd_ansible(configure_data, base_project, dryrun, verbose, destroy=False, profile=False):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode
        verbose (bool): enable more verbosity
        destroy (bool): select the playbook list
        profile (bool): enable task profile

    Returns:
        Status: execution result, 0 means OK. It is mind to be used as script exit code
    """
    sequence = 'create'
    if destroy:
        sequence = 'destroy'

    # Validations
    config = CONF(configure_data)
    if not config.has_ansible():
        return Status(f"Deployment configured without Ansible in {configure_data}")

    res, msg = ansible_validate(config, base_project, sequence, configure_data['provider'])
    if not res:
        return Status(msg)

    if not config.has_ansible_playbooks(sequence):
        log.info("No playbooks to play")
        return Status("ok")

    inventory = os.path.join(base_project, 'terraform', configure_data['provider'], 'inventory.yaml')
    ret, ansible_cmd_seq = ansible_command_sequence(configure_data['ansible'], base_project, sequence, verbose, inventory, profile)
    if not ret:
        return Status(ansible_cmd_seq)

    for command in ansible_cmd_seq:
        if dryrun:
            print(' '.join(command['cmd']))
        else:
            ret, out = lib.process_manager.subprocess_run(**command)
            log.debug("Ansible process return ret:%d", ret)
            if ret == 0:
                for out_line in out:
                    log.debug(">    %s", out_line)
            else:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(ret)
    return Status("ok")
