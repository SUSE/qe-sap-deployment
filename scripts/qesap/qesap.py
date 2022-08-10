#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import os
import argparse
import logging
import sys
import re
import subprocess
import json
from json.decoder import JSONDecodeError


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


def cmd_configure(configure_file, base_project, dryrun):
    """ Main executor for the configure sub-command

    Args:
        configure_file (str): configuration file
        base_project (str): base project path where to
                      look for the terraform and ansible folder
                      to write all the needed files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return 0


def cmd_deploy(configure_file, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_file (str): configuration file
        base_project (str): base project path where to
                      look for the Terraform and Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return 0


def cmd_destroy(configure_file, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_file (str): configuration file
        base_project (str): base project path where to
                      look for the Terraform and Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return 0


def cmd_terraform(configure_file, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_file (str): configuration file
        base_project (str): base project path where to
                      look for the Terraform files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return 0


def cmd_ansible(configure_file, base_project, dryrun):
    """ Main executor for the deploy sub-command

    Args:
        configure_file (str): configuration file
        base_project (str): base project path where to
                      look for the Ansible files
        dryrun (bool): enable dryrun execution mode

    Returns:
        int: execution result, 0 means OK. It is mind to be used as script exit code
    """
    return 0


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
    parser.add_argument('-c', '--config-file', dest='config_file',
    type=str,
    help="""Input global configuration .yaml file""")
    parser.add_argument('-b', '--base-dir', dest='basedir',
    type=is_dir,
    required=True,
    #default=None,
    help="""Base project folder, used to figure out
    where to write all the generated configuration files and
    where they are stored when it is time to call Terraform and Ansible.
    It has to be created in advance.
    Files created there:
    - terraform/{CLOUDPROVIDER}/terraform.tfvars
    - ...
    """)
    # Sub-commands
    subparsers = parser.add_subparsers(dest='command')

    parser_configure = subparsers.add_parser('configure')
    parser_deploy = subparsers.add_parser('deploy')
    parser_destroy = subparsers.add_parser('destroy')
    parser_terraform = subparsers.add_parser('terraform')
    parser_ansible = subparsers.add_parser('ansible')


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
        return cmd_configure(
            parsed_args.config_file,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "deploy":
        log.info("Deploying...")
        return cmd_deploy(
            parsed_args.config_file,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "destroy":
        log.info("Destroying...")
        return cmd_destroy(
            parsed_args.config_file,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "terraform":
        log.info("Running Terraform...")
        return cmd_terraform(
            parsed_args.config_file,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    elif parsed_args.command == "ansible":
        log.info("Running Ansible...")
        return cmd_ansible(
            parsed_args.config_file,
            parsed_args.basedir,
            parsed_args.dryrun
        )
    else:
        log.error("Unknown command:%s", parsed_args.command)
        return 1


if __name__ == "__main__":
    sys.exit(main())
