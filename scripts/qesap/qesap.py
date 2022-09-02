#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import os
import argparse
import logging
import sys
import subprocess
import re
import yaml
from yaml.parser import ParserError
from yaml.scanner import ScannerError
from lib.config import yaml_to_tfvars, template_to_tfvars, terraform_yml

VERSION = '0.1'

DESCRIBE = '''qe-sap-deployment helper script'''


# Logging config
logging.basicConfig()
log = logging.getLogger('QESAPDEP')


def os_path_exists(path):
    """Tiny os.path.exists wrapper
    Mostly used to be able to mock os.path.exists only for the code under test
    and not in the overall runtime. It is to avoid problems using the debugger

    Args:
        path (Union[AnyStr, _PathLike[AnyStr]]): path

    Returns:
        bool: Test whether a path exists.
    """
    return os.path.exists(path)


def subprocess_run(cmd):
    """Tiny wrapper around subprocess

    Args:
        cmd (list of string): directly used as input for subprocess.run

    Returns:
        (int, list of string): exit code and list of stdout
    """
    if 0 == len(cmd):
        log.error("Empty command")
        return (1, [])

    log.info("Run:       %s", ' '.join(cmd))
    stdout = []
    if sys.version_info.major == 3 and sys.version_info.minor > 7:
        proc = subprocess.run(cmd, capture_output=True, check=False)
        if proc.returncode != 0:
            log.error("Error %d in %s", proc.returncode, ' '.join(cmd[0:1]))
            for err_line in proc.stderr.decode('UTF-8').splitlines():
                log.error("STDERR:          %s", err_line)
            for err_line in proc.stdout.decode('UTF-8').splitlines():
                log.error("STDOUT:          %s", err_line)
            return (proc.returncode, [])
        stdout = [line.decode("utf-8") for line in proc.stdout.splitlines()]
    else:
        import select
        with subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE) as proc:
            poller_out = select.epoll()
            poller_out.register(proc.stdout.fileno(), select.EPOLLIN)
            poller_err = select.epoll()
            poller_err.register(proc.stderr.fileno(), select.EPOLLIN)

            while True:
                events_out = poller_out.poll(1)
                # log.debug("Events out:%s", events_out)
                for fdout_stream, _ in events_out:
                    if fdout_stream != proc.stdout.fileno():
                        log.error("fd:%s proc.stdout.fileno():%s", fdout_stream, proc.stdout.fileno())
                        continue
                    data = os.read(fdout_stream, 1024)
                    data_str = data.decode(encoding='utf-8', errors='ignore')
                    if data_str:
                        log.debug("Split:%s", data_str.splitlines())
                        stdout += data_str.splitlines()
                if proc.poll() is not None:
                    log.info('Done')
                    break
            if proc.returncode != 0:
                log.error("Error %d in %s", proc.returncode, ' '.join(cmd[0:1]))
                events_err = poller_err.poll(1)
                log.debug("Events err:%s", events_err)
                for fdout_stream, _ in events_err:
                    if fdout_stream != proc.stderr.fileno():
                        log.error("fd:%s proc.stderr.fileno():%s", fdout_stream, proc.stdout.fileno())
                        continue
                    data = os.read(fdout_stream, 1024)
                    log.error(data.decode(encoding="utf-8", errors="ignore").strip())
                log.info("Stdout:%s", stdout)
                return (proc.returncode, [])

    for line in stdout:
        log.debug('Stdout:%s', line)
    return (0, stdout)


def validate_config(config):
    """
    Validate the mandatory and common part of the internal structure of the configure.yaml
    """
    log.debug("Configure data:%s", config)
    if config is None:
        log.error("Empty config")
        return False

    if (
        "apiver" not in config.keys()
        or config["apiver"] is None
        or not isinstance(config["apiver"], int)
    ):
        log.error("Error at 'apiver' in the config")
        return False

    if (
        "provider" not in config.keys()
        or config["provider"] is None
        or not isinstance(config["provider"], str)
    ):
        log.error("Error at 'provider' in the config")
        return False

    return True


def validate_ansible_config(config, sequence):
    '''
    Validate the ansible part of the internal structure of the configure.yaml
    '''
    log.debug("Configure data:%s", config)

    if 'ansible' not in config.keys() or config['ansible'] is None:
        log.error("Error at 'ansible' in the config")
        return False

    if 'hana_urls' not in config['ansible'].keys():
        log.error("Missing 'hana_urls' in 'ansible' in the config")
        return False

    if sequence:
        if sequence not in config['ansible'].keys() or config['ansible'][sequence] is None:
            log.info('No Ansible playbooks to play in %s for sequence:%s', config['ansible'], sequence)
            return False

    return True


def validate_basedir(basedir, config):
    '''
    Validate the file and folder structure of the main repository
    '''
    terraform_dir = os.path.join(basedir, 'terraform')
    result = {
        'terraform': terraform_dir,
        'provider': None,
        'tfvars': None,
        'tfvars_template': None,
        'hana_vars': None
    }

    if not os.path.isdir(terraform_dir):
        log.error("Missing %s", terraform_dir)
        return False, None
    result['provider'] = os.path.join(terraform_dir, config['provider'])
    if not os.path.isdir(result['provider']):
        log.error("Missing %s", result['terraform'])
        return False, None
    tfvar_template_path = os.path.join(result['provider'], 'terraform.tfvars.template')
    # In case of template missing, it will be created from config.yaml
    if os.path.isfile(tfvar_template_path):
        result['tfvars_template'] = tfvar_template_path

    ansible_pl_vars_dir = os.path.join(basedir, 'ansible', 'playbooks', 'vars')
    if not os.path.isdir(ansible_pl_vars_dir):
        log.error("Missing %s", ansible_pl_vars_dir)
        return False, None

    result['tfvars'] = os.path.join(result['provider'], 'terraform.tfvars')
    result['hana_vars'] = os.path.join(ansible_pl_vars_dir, 'azure_hana_media.yaml')

    return True, result


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
    if not validate_config(configure_data):
        return 1, f"Invalid configuration file content in {configure_data}"
    res, cfg_paths = validate_basedir(base_project, configure_data)
    if not res:
        return 1, f"Invalid folder structure at {base_project}"

    # Just an handy alias
    tfvar_path = cfg_paths['tfvars']
    hana_vars = cfg_paths['hana_vars']

    if cfg_paths['tfvars_template']:
        log.debug("tfvar template %s", cfg_paths['tfvars_template'])
        tfvar_content = template_to_tfvars(cfg_paths['tfvars_template'], configure_data)
    elif terraform_yml(configure_data):
        log.debug("tfvar template not present")
        tfvar_content = yaml_to_tfvars(configure_data)
        if tfvar_content is None:
            return 1, "Problem converting config.yaml content to terraform.tfvars"
    else:
        return 1, "No terraform.tfvars.template neither terraform in the configuration"

    if validate_ansible_config(configure_data, None):
        hanavar_content = {'hana_urls': configure_data['ansible']['hana_urls']}
        log.debug("Result %s:\n%s", hana_vars, hanavar_content)

    if dryrun:
        print(f"Create {tfvar_path} with content {tfvar_content}")
        print(f"Create {hana_vars} with content {hanavar_content}")
    else:
        log.info("Write %s", tfvar_path)
        with open(tfvar_path, 'w', encoding='utf-8') as file:
            file.write(''.join(tfvar_content))
        log.info("Write %s", hana_vars)
        with open(hana_vars, 'w', encoding='utf-8') as file:
            yaml.dump(hanavar_content, file)
    return 0, 'ok'


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
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """

    # Validations
    if not validate_config(configure_data):
        return 1, f"Invalid configuration file content in {configure_data}"
    res, cfg_paths = validate_basedir(base_project, configure_data)
    if not res:
        return 1, f"Invalid folder structure at {base_project}"

    cmds = []
    for seq in ['init', 'plan', 'apply'] if not destroy else ['destroy']:
        this_cmd = []
        this_cmd.append('terraform')
        this_cmd.append('-chdir=' + cfg_paths['provider'])
        this_cmd.append(seq)
        if seq == 'plan':
            this_cmd.append('-out=plan.zip')
        elif seq == 'apply':
            this_cmd.append('-auto-approve')
            this_cmd.append('plan.zip')
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
                return ret, f"Error at {command}"
    return 0, 'Ok'


def cmd_ansible(configure_data, base_project, dryrun, verbose, destroy=False):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """

    # Validations
    if not validate_config(configure_data):
        return 1, f"Invalid configuration file content in {configure_data}"

    sequence = 'create'
    if destroy:
        sequence = 'destroy'

    if not validate_ansible_config(configure_data, sequence):
        log.info('No Ansible playbooks to play in %s', configure_data)
        return 0

    inventory = os.path.join(base_project, 'terraform', configure_data['provider'], 'inventory.yaml')
    if not os.path.isfile(inventory):
        log.error("Missing inventory at %s", inventory)
        return 1, "Missing inventory"

    ansible_common = ['ansible-playbook']
    if verbose:
        ansible_common.append('-vvvv')

    ansible_common.append('-i')
    ansible_common.append(inventory)

    ansible_cmd = []
    ansible_cmd_seq = []
    ssh_share = ansible_common.copy()
    ssh_share[0] = 'ansible'
    ssh_share.append('all')
    ssh_share.append('-a')
    ssh_share.append('true')
    ssh_share.append('--ssh-extra-args="-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new"')
    ansible_cmd_seq.append(ssh_share)

    for playbook in configure_data['ansible'][sequence]:
        ansible_cmd = ansible_common.copy()
        playbook_cmd = playbook.split(' ')
        log.debug("playbook:%s", playbook)
        playbook_filename = os.path.join(base_project, 'ansible', 'playbooks', playbook_cmd[0])
        if not os.path.isfile(playbook_filename):
            log.error("Missing playbook at %s", playbook_filename)
            return 1
        ansible_cmd.append(playbook_filename)
        for ply_cmd in playbook_cmd[1:]:
            match = re.search(r'\${(.*)}', ply_cmd)
            if match:
                value = str(configure_data['ansible']['variables'][match.group(1)])
                log.debug("Replace value %s in %s", value, ply_cmd)
                ansible_cmd.append(re.sub(r'\${(.*)}', value, ply_cmd))
            else:
                ansible_cmd.append(ply_cmd)
        ansible_cmd_seq.append(ansible_cmd)

    for command in ansible_cmd_seq:
        if dryrun:
            print(' '.join(command))
        else:
            ret, out = subprocess_run(command)
            for out_line in out:
                log.debug(">    %s", out_line)
            log.debug("Ansible process return ret:%d", ret)
            if ret != 0:
                log.error("command:%s returned non zero %d", command, ret)
                return ret
    return 0


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
    '''
    Command line argument parser
    '''
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


def main(command_line=None):
    '''
    Main script entry point for command line execution
    '''
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
        return res[0]
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
        res, err = cmd_terraform(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun,
            destroy=parsed_args.destroy
        )
        if res != 0:
            print(err)
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
