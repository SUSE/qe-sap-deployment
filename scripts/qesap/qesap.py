#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import os
import argparse
import logging
import sys
import shutil
import subprocess
import re
import yaml
from yaml.parser import ParserError
from yaml.scanner import ScannerError
from lib.config import CONF

VERSION = '0.2'

DESCRIBE = '''qe-sap-deployment helper script'''


# Logging config
logging.basicConfig()
log = logging.getLogger('QESAPDEP')


class Status(int):
    """
    This class inherits from int (interpreted as a return value) to add an error message
    >>> e = Status("ok")
    >>> print(e, e.msg)
    0 ok
    >>> e = Status("something bad happened")
    >>> print(e, e.msg)
    1 something bad happened
    >>> e = Status(777)
    >>> print(e, e.msg)
    777 777
    """
    msg = ""

    def __new__(cls, str_or_int):
        if isinstance(str_or_int, str):
            value = 0 if str_or_int == "ok" else 1
        elif isinstance(str_or_int, int):
            value = int(str_or_int)
        obj = super().__new__(cls, value)
        obj.msg = str(str_or_int)
        return obj


def subprocess_run(cmd, env=None):
    """Tiny wrapper around subprocess

    Args:
        cmd (list of string): directly used as input for subprocess.run

    Returns:
        (int, list of string): exit code and list of stdout
    """
    if 0 == len(cmd):
        log.error("Empty command")
        return (1, [])

    log.info("Run:       '%s'", ' '.join(cmd))
    if env is not None:
        log.info("with env %s", env)

    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, env=env)
    if proc.returncode != 0:
        log.error("Error %d in %s", proc.returncode, ' '.join(cmd[0:1]))
        for err_line in proc.stderr.decode('UTF-8').splitlines():
            log.error("STDERR:          %s", err_line)
        for err_line in proc.stdout.decode('UTF-8').splitlines():
            log.error("STDOUT:          %s", err_line)
        return (proc.returncode, [])
    stdout = [line.decode("utf-8") for line in proc.stdout.splitlines()]

    for line in stdout:
        log.debug('Stdout:%s', line)
    return (0, stdout)


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

    if cfg_paths['tfvars_template']:
        log.debug("tfvar template %s", cfg_paths['tfvars_template'])
        tfvar_content = config.template_to_tfvars(cfg_paths['tfvars_template'])
    elif config.terraform_yml():
        log.debug("tfvar template not present")
        tfvar_content = config.yaml_to_tfvars()
        if tfvar_content is None:
            return Status("Problem converting config.yaml content to terraform.tfvars")
    else:
        return Status("No terraform.tfvars.template neither terraform in the configuration")

    if not config.validate_ansible_config(None):
        return Status("Problems in the ansible part of the configuration")

    hanamedia_content = {'hana_urls': configure_data['ansible']['hana_urls']}
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
    return 0


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
    return 0


def cmd_terraform(configure_data, base_project, dryrun, destroy=False):
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
    for seq in ['init', 'plan', 'apply'] if not destroy else ['destroy']:
        this_cmd = ['terraform', f"-chdir={cfg_paths['provider']}", seq]
        if seq == 'plan':
            this_cmd.append('-out=plan.zip')
        elif seq == 'apply':
            this_cmd.extend(['-auto-approve', 'plan.zip'])
        elif seq == 'destroy':
            this_cmd.append('-auto-approve')
        this_cmd.append('-no-color')
        cmds.append(this_cmd)
    for command in cmds:
        if dryrun:
            print(' '.join(command))
        else:
            ret, out = subprocess_run(command)
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


def cmd_ansible(configure_data, base_project, dryrun, verbose, destroy=False):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        Status: execution result, 0 means OK. It is mind to be used as script exit code
    """

    # Validations
    config = CONF(configure_data)
    if not config.validate():
        return Status(f"Invalid configuration file content in {configure_data}")

    sequence = 'create'
    if destroy:
        sequence = 'destroy'

    if not config.validate_ansible_config(sequence):
        log.info('No Ansible playbooks to play in %s', configure_data)
        return Status("ok")

    inventory = os.path.join(base_project, 'terraform', configure_data['provider'], 'inventory.yaml')
    if not os.path.isfile(inventory):
        log.error("Missing inventory at %s", inventory)
        return Status("Missing inventory")

    ansible_common = [shutil.which('ansible-playbook')]
    if verbose:
        ansible_common.append('-vvvv')

    ansible_common.append('-i')
    ansible_common.append(inventory)

    ansible_cmd = []
    ansible_cmd_seq = []
    ssh_share = ansible_common.copy()
    ssh_share[0] = shutil.which('ansible')
    ssh_share.extend([
        'all', '-a', 'true',
        '--ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"'])
    ansible_cmd_seq.append({'cmd': ssh_share})

    for playbook in configure_data['ansible'][sequence]:
        ansible_cmd = ansible_common.copy()
        playbook_cmd = playbook.split(' ')
        log.debug("playbook:%s", playbook)
        playbook_filename = os.path.join(base_project, 'ansible', 'playbooks', playbook_cmd[0])
        if not os.path.isfile(playbook_filename):
            log.error("Missing playbook at %s", playbook_filename)
            return Status("Missing playbook")
        ansible_cmd.append(playbook_filename)
        for ply_cmd in playbook_cmd[1:]:
            match = re.search(r'\${(.*)}', ply_cmd)
            if match:
                value = str(configure_data['ansible']['variables'][match.group(1)])
                log.debug("Replace value %s in %s", value, ply_cmd)
                ansible_cmd.append(re.sub(r'\${(.*)}', value, ply_cmd))
            else:
                ansible_cmd.append(ply_cmd)
        ansible_cmd_seq.append({'cmd': ansible_cmd, 'env': {'ANSIBLE_PIPELINING': 'True'}})

    for command in ansible_cmd_seq:
        if dryrun:
            print(' '.join(command))
        else:
            ret, out = subprocess_run(**command)
            for out_line in out:
                log.debug(">    %s", out_line)
            log.debug("Ansible process return ret:%d", ret)
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return Status(ret)
    return Status("ok")


def is_yaml(path):
    """ argparser validator for YAML files

    Args:
        path (str)): path of the file to validate

    Raises:
        argparse.ArgumentTypeError: if the file does not exist
        or it is not a valid YAML file

    Returns:
        str: the validated file
    """
    if not os.path.isfile(path):
        # raise SystemExit
        raise argparse.ArgumentTypeError("is_yaml:" + path + " is not a file")

    with open(path, 'r', encoding='utf-8') as file:
        try:
            data = yaml.load(file, Loader=yaml.FullLoader)
        except (ScannerError, ParserError) as exc:
            raise argparse.ArgumentTypeError("is_yaml:" + path + " is not a valid YAML file") from exc
    return data


def is_dir(path):
    """ argparser validator for directory

    Args:
        path (str)): path to validate

    Raises:
        argparse.ArgumentTypeError: if the folder does not exist

    Returns:
        str: the validated path
    """
    if os.path.isdir(path):
        return path
    # raise SystemExit
    raise argparse.ArgumentTypeError("is_dir:" + path + " is not a folder")


def cli(command_line=None):
    """
    Command line argument parser
    """
    parser = argparse.ArgumentParser(description=DESCRIBE)

    parser.add_argument('--version', action='version', version=VERSION)
    parser.add_argument('--verbose', action='store_true', help="Increases log verbosity")
    parser.add_argument('--dryrun', action='store_true', help="Dry run execution mode")

    parser.add_argument(
        '-c', '--config-file', dest='configfile',
        type=is_yaml,
        required=True,
        help="""Input global configuration .yaml file""")

    parser.add_argument(
        '-b', '--base-dir', dest='basedir',
        type=is_dir,
        required=True,
        help="""Base project folder, used to figure out
    where to write all the generated configuration files and
    where they are stored when it is time to call Terraform and Ansible.
    It has to be created in advance.
    Files created there:
    - terraform/{CLOUDPROVIDER}/terraform.tfvars
    - ...
    """)
    # Sub-commands
    subparsers = parser.add_subparsers(
        description='''List of qesap subcommands, each of them is usually associated to a specific procedure''',
        dest='command')

    subparsers.add_parser('configure',
                          help="""Generate all Terraform, Ansible configuration file
                                  starting from the main global YAML configuration file""")
    subparsers.add_parser('deploy', help="Run, in sequence, the Terraform and Ansible deployment steps")
    subparsers.add_parser('destroy', help="Run, in sequence, the Ansible and Terraform destroy steps")
    parser_terraform = subparsers.add_parser('terraform', help="Only run the Terraform part of the deployment")
    parser_terraform.add_argument('-d',
                                  '--destroy',
                                  action='store_true',
                                  help='Only destroy terraform setup, without executing ansible')
    parser_ansible = subparsers.add_parser('ansible', help="Only run the Ansible part of the deployment")
    parser_ansible.add_argument('-d',
                                '--destroy',
                                action='store_true',
                                help='Only destroy terraform setup, without executing ansible')

    parsed_args = parser.parse_args(command_line)
    return parsed_args


def main(command_line=None):  # pylint: disable=too-many-return-statements
    """
    Main script entry point for command line execution
    """
    parsed_args = cli(command_line)

    if parsed_args.verbose:
        log.setLevel(logging.getLevelName('DEBUG'))

    if not parsed_args.command:
        log.debug("No command")
        return 0

    if parsed_args.command == "configure":
        log.info("Configuring...")
        res = cmd_configure(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun
        )
        return res
    if parsed_args.command == "deploy":
        log.info("Deploying...")
        return cmd_deploy(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    if parsed_args.command == "destroy":
        log.info("Destroying...")
        return cmd_destroy(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    if parsed_args.command == "terraform":
        log.info("Running Terraform...")
        res = cmd_terraform(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun,
            destroy=parsed_args.destroy
        )
        if res != 0:
            print(res.msg)  # should we use file=sys.stderr here?
        return res
    if parsed_args.command == "ansible":
        log.info("Running Ansible...")
        return cmd_ansible(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun,
            parsed_args.verbose,
            destroy=parsed_args.destroy
        )

    log.error("Unknown command:%s", parsed_args.command)
    return 1


if __name__ == "__main__":
    sys.exit(main())
