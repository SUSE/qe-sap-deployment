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
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()

    calls = []
    terraform_cmd = [
        'terraform',
        f"-chdir=\"{terraform_dir}\""]
    if isinstance(terraform_cmd_args, str):
        terraform_cmd.append(terraform_cmd_args)
    else:
        for arg in terraform_cmd_args:
            terraform_cmd.append(arg)
    terraform_cmd.append('-no-color')
    calls.append(mock.call(terraform_cmd))

    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_terraform_logs(run, terraform_cmd_args, args_helper, config_yaml_sample, tmpdir):
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
        f"-chdir=\"{terraform_dir}\"",
        'destroy',
        '-auto-approve',
        '-no-color']))

    assert main(args) == 0
    run.assert_called()
    run.assert_has_calls(calls)