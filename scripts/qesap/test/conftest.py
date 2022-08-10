from unittest import mock
import json

import pytest


@pytest.fixture
def compose_default_subprocess_run_calls():
    """
    Compose a standard list of expected calls to subprocess.run
    """
    def _callback(acr_name):
        calls = list()
        calls.append(mock.call(['mkdir', '/tmp/charts']))
        calls.append(
            mock.call(
                [
                    "helm",
                    "pull",
                    "-d",
                    "/tmp/charts",
                    "oci://registry.suse.com/trento/trento-server",
                ]))
        calls.append(
            mock.call(
                [
                    "helm",
                    "push",
                    "/tmp/charts/something.tgz",
                    "oci://" + acr_name + "/trento",
                ]))
        return calls
    return _callback


@pytest.fixture
def base_args():
    """
    Return bare minimal list of arguments to run any sub-command
    Args:
        x (str): x used for -x
        output (str): output folder for --output
    """
    def _callback(basedir):
        return ['--verbose', '--base-dir', str(basedir)]
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
