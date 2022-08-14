from unittest import mock
import json
import os

import pytest

@pytest.fixture
def base_args(tmpdir):
    """
    Return bare minimal list of arguments to run any sub-command
    Args:
        base_dir (str): used for -b
        config_file (str): used for -c
    """
    def _callback(base_dir=None, config_file=None):
        args = list()
        args.append('--verbose')

        args.append('--base-dir')
        if base_dir is None:
            args.append(str(tmpdir))
        else:
            args.append(str(base_dir))

        args.append('--config-file')
        if config_file is None:
            config_file_name = str(tmpdir / 'config.yaml')
            with open(config_file_name, 'w') as file:
                file.write("")
            args.append(config_file_name)
        else:
            args.append(config_file)

        return args

    return _callback


@pytest.fixture
def args_helper(tmpdir, base_args):
    def _callback(provider, conf, tfvar):
        provider_path = os.path.join(tmpdir,'terraform', provider)
        if not os.path.isdir(provider_path):
            os.makedirs(provider_path)
        tfvar_path = os.path.join(provider_path,'terraform.tfvars')

        ansiblevars_path = os.path.join(tmpdir,'ansible', 'playbooks', 'vars')
        if not os.path.isdir(ansiblevars_path):
            os.makedirs(ansiblevars_path)
        hana_vars = os.path.join(ansiblevars_path, 'azure_hana_media.yaml')

        config_file_name = str(tmpdir / 'config.yaml')
        with open(config_file_name, 'w') as file:
            file.write(conf)
        with open(os.path.join(provider_path, 'terraform.tfvars.template'), 'w') as file:
            for line in tfvar:
                file.write(line)

        args = base_args(base_dir=tmpdir, config_file=config_file_name)

        return args, tfvar_path, hana_vars

    return _callback


@pytest.fixture
def configure_helper(args_helper):
    def _callback(provider, conf, tfvar):
        args, tfvar_path, hana_vars = args_helper(provider, conf, tfvar)
        args.append('configure')
        return args, tfvar_path, hana_vars

    return _callback


@pytest.fixture
def create_config():
    """Create one element for the list in the configure.json related to trento_deploy.py -s
    """
    def _callback(typ, reg, ver):
        config = dict()
        config['type'] = typ
        config['registry'] = reg
        if ver:
            config['version'] = ver
        return config
    return _callback


@pytest.fixture
def line_match():
    """
    return True if matcher string is present at least one in the string_list
    """
    def _callback(string_list, matcher):
        return len([s for s in string_list if matcher in s]) > 0
    return _callback


@pytest.fixture
def check_duplicate():
    """
    Fixture to test trento_cluster_install.sh content
    Check for duplicated lines

    Args:
        lines (list(str)): list of string, each string is a trento_cluster_install.sh line

        Returns:
            tuple: True/False result, if False str about the error message
        """
    def _callback(lines):
        for line in lines:
            if len([s for s in lines if line.strip() in s.strip()]) != 1 :
                return (False, "Line '"+line+"' appear more than one time")
            if '--set' in line:
                setting = line.split(' ')[1]
                setting_field = setting.split('=')[0]
                if len([s for s in lines if setting_field in s]) != 1 :
                    return (False, "Setting '"+setting_field+"' appear more than one time")
        return (True, '')
    return _callback


@pytest.fixture
def check_multilines():
    """
    Fixture to test trento_cluster_install.sh content
    This bash script is written to file as multiple line single command
    This fixture check that:
     - each lines (out of the last one) ends with \\ and EOL
     - all needed EOL are present
     - all and only needed spaces are present at the end of each line

    Args:
        lines (list(str)): list of string, each string is a trento_cluster_install.sh line

        Returns:
            tuple: True/False result, if False str about the error message
        """
    def _callback(lines):
        if len(lines) <= 1:
            return False, "trento_cluster_install.sh should be a multi line script but it is only " + str(len(lines)) + " lines long."
        for l in lines[:-1]:
            if l[-1] != "\n":
                return False, "Last char in ["+l+"] is not \n"
            # in multi line command the '\' has to be the last char in the line
            if l[-2] != "\\":
                return False, "One by last char in ["+l+"] is not \\"
            if l[-3] != " ":
                return False, "One by last char in ["+l+"] is not a space"
            if "\\-" in l:
                return False, "Something like '\\--set' in ["+l+"]. Maybe a missing EOL"
        return (True, '')
    return _callback


@pytest.fixture
def check_manadatory_args(capsys, tmpdir):
    '''
    Given a cli to test and a subcommand string,
    check that both -c and -b are mandatory
    '''
    def _callback(cli_to_test, subcmd):
        try:
            cli_to_test([subcmd])
        except SystemExit:
            pass
        captured = capsys.readouterr()
        if 'error:' not in captured.err:
            return False

        # Try with b but without c
        try:
            cli_to_test(['-b', str(tmpdir), subcmd])
        except SystemExit:
            pass
        captured = capsys.readouterr()
        if 'error:' not in captured.err:
            return False

        # Try with c but without b
        try:
            cli_to_test(['-c', str(tmpdir), subcmd])
        except SystemExit:
            pass
        captured = capsys.readouterr()
        if 'error:' not in captured.err:
            return False

        return True

    return _callback
