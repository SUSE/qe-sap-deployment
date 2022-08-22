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
from string import Template


VERSION  = '0.1'

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

    log.info("Run:%s", ' '.join(cmd))
    stdout = []
    if sys.version_info.major == 3 and sys.version_info.minor > 7 :
        proc = subprocess.run(cmd, capture_output=True, check=False)
        if proc.returncode != 0:
            log.error("Error %d in %s", proc.returncode, ' '.join(cmd[0:1]))
            log.error(proc.stderr)
            return (proc.returncode, [])
        stdout = [l.decode("utf-8") for l in proc.stdout.splitlines()]
    else:
        import select
        proc = subprocess.Popen(cmd,
               stdout=subprocess.PIPE,
               stderr=subprocess.PIPE)
        poller_out = select.epoll()
        poller_out.register(proc.stdout.fileno(), select.EPOLLIN)
        poller_err = select.epoll()
        poller_err.register(proc.stderr.fileno(), select.EPOLLIN)

        while True:
            events_out = poller_out.poll(1)
            #log.debug("Events out:%s", events_out)
            for fd, _ in events_out:
                if fd != proc.stdout.fileno():
                    log.error("fd:%s proc.stdout.fileno():%s", fd, proc.stdout.fileno())
                    continue
                data = os.read(fd, 1024)
                data_str = data.decode(encoding="utf-8", errors="ignore")
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
            for fd, _ in events_err:
                if fd != proc.stderr.fileno():
                    log.error("fd:%s proc.stderr.fileno():%s", fd, proc.stdout.fileno())
                    continue
                data = os.read(fd, 1024)
                log.error(data.decode(encoding="utf-8", errors="ignore").strip())
            log.info("Stdout:%s", stdout)
            return (proc.returncode, [])

    for l in stdout:
        log.debug('Stdout:%s',l)
    return (0, stdout)


def validate_config(config):
    log.debug("Configure data:%s", config)
    if config is None:
        log.error("Empty config")
        return False

    if 'terraform' not in config.keys():
        log.error("Missing key terraform in the config")
        return False

    if config['terraform'] is None or 'provider' not in config['terraform'].keys():
        log.error("Missing 'provider' key in the config['terraform']")
        return False

    if config['terraform']['provider'] is None:
        log.error("Empty 'provider' in the config")
        return False

    if not 'ansible' in config.keys() or config['ansible'] is None:
        log.error("Empty 'ansible' in the config")
        return False

    if not 'hana_urls' in config['ansible'].keys():
        log.error("Missing 'hana_urls' in 'ansible' in the config")
        return False

    return True


def validate_basedir(basedir, config):
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
    result['provider'] = os.path.join(terraform_dir, config['terraform']['provider'])
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

    result['tfvars'] = os.path.join(result['provider'],'terraform.tfvars')
    result['hana_vars'] = os.path.join(ansible_pl_vars_dir,'azure_hana_media.yaml')

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

    # Create tfvars file
    tfvar_content = []
    if cfg_paths['tfvars_template']:
        with open(cfg_paths['tfvars_template'], 'r') as f:
            tfvar_content = f.readlines()
            log.debug("Template:%s", tfvar_content)

        if 'variables' in configure_data['terraform'].keys():
            log.debug("Config has terraform variables")
            for k,v in configure_data['terraform']['variables'].items():
                key_replace = False
                # Look for k in the template file content
                for index, line in enumerate(tfvar_content):
                    match = re.search(k+r'\s?=.*', line)
                    if match:
                        log.debug("Replace template %s with [%s = %s]", line, k, v)
                        tfvar_content[index] = f"{k} = {v}\n"
                        key_replace = True
                # add the new key/value pair
                if not key_replace:
                    log.debug("[k:%s = v:%s] is not in the template, append it", k, v)
                    tfvar_content.append(f"{k} = {v}\n")
        log.debug("Result terraform.tfvars:\n%s", tfvar_content)
    hanavar_content = {}
    hanavar_content['hana_urls'] = configure_data['ansible']['hana_urls']
    log.debug("Result %s:\n%s", hana_vars, hanavar_content)
    if dryrun:
        print(f"Create {tfvar_path} with content {tfvar_content}")
        print(f"Create {hana_vars} with content {hanavar_content}")
    else:
        with open(tfvar_path, 'w', encoding='utf-8') as file:
            file.write(''.join(tfvar_content))
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
    if not validate_config(configure_data):
        return 1, f"Invalid configuration file content in {configure_data}"
    res, cfg_paths = validate_basedir(base_project, configure_data)
    if not res:
        return 1, f"Invalid folder structure at {base_project}"

    sequence = ['init', 'plan', 'apply'] if not destroy else ['destroy']
    cmds = [[], [], []] if not destroy else [[]]

    for idx, seq in enumerate(sequence):
        cmds[idx].append(f"TF_LOG_PATH=terraform.{seq}.log.txt")
        cmds[idx].append('TF_LOG=INFO')
        cmds[idx].append('terraform')
        cmds[idx].append('-chdir="' + cfg_paths['provider'] + '"')
        cmds[idx].append(seq)
        if seq == 'plan':
            cmds[idx].append('-out=plan.zip')
        elif seq == 'apply':
            cmds[idx].append('-auto-approve')
            cmds[idx].append('plan.zip')
        elif seq == 'destroy':
            cmds[idx].append('-auto-approve')
        cmds[idx].append('-no-color')
    for command in cmds:
        if dryrun:
            print(command)
        else:
            log.debug("Add call:%s", command)
            ret, out = subprocess_run(command)
            log.debug("Terraform process return ret:%s out:%s", ret, out)
    return 0


def cmd_ansible(configure_data, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_data (obj): configuration structure
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
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
        #raise SystemExit
        raise argparse.ArgumentTypeError("is_yaml:" + path + " is not a file")

    with open(path, 'r', encoding='utf-8') as file:
        try:
            data = yaml.load(file, Loader=yaml.FullLoader)
        except (ScannerError, ParserError):
            raise argparse.ArgumentTypeError("is_yaml:" + path + " is not a valid YAML file")
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
    else:
        #raise SystemExit
        raise argparse.ArgumentTypeError("is_dir:" + path + " is not a folder")


def cli(command_line=None):
    '''
    Command line argument parser
    '''
    parser   = argparse.ArgumentParser(description=DESCRIBE)

    parser.add_argument('--version', action='version', version=VERSION)
    parser.add_argument('--verbose', action='store_true', help="Increases log verbosity")
    parser.add_argument('--dryrun',  action='store_true', help="Dry run execution mode")

    parser.add_argument('-c', '--config-file', dest='configfile',
    type=is_yaml,
    required=True,
    help="""Input global configuration .yaml file""")

    parser.add_argument('-b', '--base-dir', dest='basedir',
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

    parser_configure = subparsers.add_parser('configure', help="Generate all Terraform, Ansible configuration file starting from the main global YAML configuration file")
    parser_deploy = subparsers.add_parser('deploy', help="Run, in sequence, the Terraform and Ansible deployment steps")
    parser_destroy = subparsers.add_parser('destroy', help="Run, in sequence, the Ansible and Terraform destroy steps")
    parser_terraform = subparsers.add_parser('terraform', help="Only run the Terraform part of the deployment")
    parser_terraform.add_argument('-d',
                                  '--destroy',
                                  action='store_true',
                                  help='Only destroy terraform setup, without executing ansible')
    parser_ansible = subparsers.add_parser('ansible', help="Only run the Ansible part of the deployment")

    parsed_args = parser.parse_args(command_line)
    return parsed_args


def main(command_line=None):
    '''
    Main script entry point for command line execution
    '''
    parsed_args = cli(command_line)

    if parsed_args.verbose :
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
    elif parsed_args.command == "deploy":
        log.info("Deploying...")
        return cmd_deploy(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "destroy":
        log.info("Destroying...")
        return cmd_destroy(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "terraform":
        log.info("Running Terraform...")
        return cmd_terraform(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun,
            destroy=parsed_args.destroy
        )
    elif parsed_args.command == "ansible":
        log.info("Running Ansible...")
        return cmd_ansible(
            parsed_args.configfile,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    else:
        log.error("Unknown command:%s", parsed_args.command)
        return 1


if __name__ == "__main__":
    sys.exit(main())
