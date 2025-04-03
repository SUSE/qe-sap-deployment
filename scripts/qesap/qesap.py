#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import os
import argparse
import sys
import logging

import yaml
from yaml.parser import ParserError
from yaml.scanner import ScannerError
from lib.status import Status
from lib.cmds import cmd_configure, cmd_deploy, cmd_destroy, cmd_terraform, cmd_ansible

# Logging config
logging.basicConfig(format="%(levelname)-8s %(message)s")
log = logging.getLogger('QESAP')


VERSION = '0.5'

DESCRIBE = '''qe-sap-deployment helper script'''


def load_yaml(path):
    """ argparser validator for YAML files and convert the file to a python data structure

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
        raise argparse.ArgumentTypeError("load_yaml:" + path + " is not a file")

    with open(path, 'r', encoding='utf-8') as file:
        try:
            data = yaml.load(file, Loader=yaml.FullLoader)
        except (ScannerError, ParserError) as exc:
            raise argparse.ArgumentTypeError("load_yaml:" + path + " is not a valid YAML file") from exc
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
        '-c', '--config-file', dest='configdata',
        type=load_yaml,
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
                                  help='Call terraform destroy')
    parser_terraform.add_argument('-w',
                                  '--workspace',
                                  dest='workspace',
                                  default='default',
                                  help="""Workspace to use in terraform commands. Defaults to 'default'""")
    parser_ansible = subparsers.add_parser('ansible', help="Run the Ansible part of the deployment")
    parser_ansible.add_argument('-d',
                                '--destroy',
                                action='store_true',
                                help='Play ansible deregister playoooks')

    parser_ansible.add_argument('--profile',
                                action='store_true',
                                help='Run Ansible with ansible.posix.profile_tasks')

    parser_ansible.add_argument('--junit',
                                help='Enable Ansible junit report and store it in provided folder')

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

    sim_message = os.getenv('QESAP_SIM_MSG')
    if sim_message:
        log.error("This is a -- %s -- simulation.", sim_message)
    sim_rc = os.getenv('QESAP_SIM_RC')
    if sim_rc:
        res = Status(int(sim_rc))
        return res

    if parsed_args.command == "configure":
        log.info("Configuring...")
        res = cmd_configure(
            parsed_args.configdata,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "deploy":
        log.info("Deploying...")
        res = cmd_deploy(
            parsed_args.configdata,
            parsed_args.basedir,
            parsed_args.dryrun,
            parsed_args.verbose
        )
    elif parsed_args.command == "destroy":
        log.info("Destroying...")
        res = cmd_destroy(
            parsed_args.configdata,
            parsed_args.basedir,
            parsed_args.dryrun,
            parsed_args.verbose
        )
    elif parsed_args.command == "terraform":
        log.info("Running Terraform...")
        res = cmd_terraform(
            parsed_args.configdata,
            parsed_args.basedir,
            parsed_args.dryrun,
            workspace=parsed_args.workspace,
            destroy=parsed_args.destroy
        )
        if res != 0:
            print(res.msg)  # should we use file=sys.stderr here?
        return res
    elif parsed_args.command == "ansible":
        log.info("Running Ansible...")
        res = cmd_ansible(
            parsed_args.configdata,
            parsed_args.basedir,
            parsed_args.dryrun,
            parsed_args.verbose,
            destroy=parsed_args.destroy,
            profile=parsed_args.profile,
            junit=parsed_args.junit
        )
    else:
        res = Status(f"Unknown command: {parsed_args.command}")

    if res != 0:
        log.error(res.msg)

    return res


if __name__ == "__main__":
    sys.exit(main())
