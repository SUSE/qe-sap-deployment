from unittest import mock
import os
import logging
log = logging.getLogger(__name__)
import pytest

from qesap import main

terraform_cmds = [
    ('init'),
    ('plan', '-out=plan.zip'),
    ('apply', '-auto-approve', 'plan.zip')
]
@mock.patch("qesap.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_call_terraform(run, terraform_cmd_args, args_helper, config_yaml_sample):
    """
    Command terraform calls all these 3:
     - 'terraform init'
     - 'terraform plan'
     - 'terraform apply'
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()

    calls = []
    terraform_cmd = [
        'terraform',
        f"-chdir={terraform_dir}"]
    if isinstance(terraform_cmd_args, str):
        terraform_cmd.append(terraform_cmd_args)
    else:
        for arg in terraform_cmd_args:
            terraform_cmd.append(arg)
    terraform_cmd.append('-no-color')
    calls.append(mock.call(terraform_cmd))

    run.assert_has_calls(calls)



@mock.patch("qesap.subprocess_run", side_effect = [(0, []),(1, []),(1, [])])
def test_terraform_stop_at_failure(run, args_helper, config_yaml_sample):
    """
    Command stop at first subprocess(terraform) with not zero exit code.
    Simulate a failure at 'terraform plan'
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')

    calls = []
    terraform_cmd_common = [
        'terraform',
        f"-chdir={terraform_dir}"]
    for terraform_cmd_args in [['init'], ['plan', '-out=plan.zip']]:
        terraform_cmd = terraform_cmd_common.copy()
        terraform_cmd += terraform_cmd_args
        terraform_cmd.append('-no-color')
        calls.append(mock.call(terraform_cmd))

    assert main(args) == 1

    run.assert_called()
    run.assert_has_calls(calls)
    assert not any(['apply' in name[0] for name, args in run.call_args_list]), 'Unexpected terraform apply call'


@mock.patch("qesap.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_logs(run, terraform_cmd_args, args_helper, config_yaml_sample, tmpdir):
    """
    Command terraform create one log file for each command:
     - terraform.{cmd}.log.txt
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    log.error(args)
    run.return_value = (0, ['This is the terraform output', 'Two lines of that'])
    assert main(args) == 0
    if isinstance(terraform_cmd_args, str):
        cmd = terraform_cmd_args
    else:
        cmd = terraform_cmd_args[0]
    assert os.path.isfile(f"terraform.{cmd}.log.txt")


@mock.patch("qesap.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_logs_content(run, terraform_cmd_args, args_helper, config_yaml_sample, tmpdir):
    """
    Each terraform log file contains terraform stdout
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    log.error(args)
    terraform_output = ['This is the terraform output', 'Two lines of that']
    run.return_value = (0, terraform_output)
    assert main(args) == 0
    if isinstance(terraform_cmd_args, str):
        cmd = terraform_cmd_args
    else:
        cmd = terraform_cmd_args[0]
    with open(f"terraform.{cmd}.log.txt", 'r') as log_file:
        log_lines = log_file.read().splitlines()
    assert terraform_output == log_lines


@pytest.mark.skip(reason="Run a true deployment")
@pytest.mark.parametrize("terraform_cmd_args", [('init')])
def test_integration_terraform(terraform_cmd_args, args_helper, config_yaml_sample, tmpdir):
    """
    Run a test with the true Terraform
    """
    provider = 'azure'
    conf = config_yaml_sample(provider)
    config_file_name = 'config.yaml'
    with open(config_file_name, 'w') as file:
        file.write(conf)
    args = list()
    args.append('--verbose')
    args.append('--base-dir')
    args.append(str(os.path.abspath(os.path.join(os.getcwd(), '..', '..'))))
    args.append('--config-file')
    args.append(config_file_name)
    args.append('terraform')
    log.error("===> args:%s", args)
    terraform_output = ['This is the terraform output\n', 'Two lines of that\n']
    assert main(args) == 0

    if isinstance(terraform_cmd_args, str):
        cmd = terraform_cmd_args
    else:
        cmd = terraform_cmd_args[0]

    log.error("===> cmd:%s", cmd)
    with open(f"terraform.{cmd}.log.txt", 'r') as log_file:
        log_lines = log_file.readlines()
    assert 'Initializing modules...\n' in log_lines


@mock.patch("qesap.subprocess_run")
def test_terraform_dryrun(run, args_helper, config_yaml_sample):
    """
    Command terraform does not call terraform executable in dryrun mode
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    args.insert(0, '--dryrun')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0

    run.assert_not_called()


@mock.patch("qesap.subprocess_run")
def test_terraform_call_terraform_destroy(run, args_helper, config_yaml_sample):
    """
    Command terraform with -d calls 'terraform destroy'
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, _, _ = args_helper(provider, conf, '')

    args.append('terraform')
    args.append('-d')
    log.error(args)

    run.return_value = (0, [])
    calls = []
    calls.append(mock.call([
        'terraform',
        f"-chdir={terraform_dir}",
        'destroy',
        '-auto-approve',
        '-no-color']))

    assert main(args) == 0
    run.assert_called()
    run.assert_has_calls(calls)