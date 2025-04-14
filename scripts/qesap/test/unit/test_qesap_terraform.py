from unittest import mock
import os
import logging
import pytest

from qesap import main

log = logging.getLogger(__name__)


terraform_cmds = [
    ('init'),
    ('plan -out=plan.zip'),
    ('apply -auto-approve plan.zip')
]


@mock.patch("lib.process_manager.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_call_terraform(subprocess_run, terraform_cmd_args, args_helper, config_yaml_sample):
    """
    Command terraform calls all these 3:
     - 'terraform init'
     - 'terraform plan'
     - 'terraform apply'

    It is implemented as parametrized test,
    so formally it is called 3 times, one for each expected terraform command.
    Each test invocation verify that one specific command is called
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, *_ = args_helper(provider, conf)
    args.append('terraform')
    subprocess_run.return_value = (0, [])
    assert main(args) == 0
    subprocess_run.assert_called()
    subprocess_run.assert_has_calls([mock.call(f"terraform -chdir={terraform_dir} {terraform_cmd_args} -no-color")])


@mock.patch("lib.process_manager.subprocess_run", side_effect=[(0, []), (1, []), (1, [])])
def test_terraform_stop_at_failure(subprocess_run, args_helper, config_yaml_sample):
    """
    Command stop at first subprocess(terraform) with not zero exit code.
    Simulate a failure at 'terraform plan'
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, *_ = args_helper(provider, conf)
    args.append('terraform')

    calls = []
    terraform_cmd_common = [
        'terraform',
        f"-chdir={terraform_dir}"]
    for terraform_cmd_args in [['init'], ['plan', '-out=plan.zip']]:
        terraform_cmd = terraform_cmd_common.copy()
        terraform_cmd += terraform_cmd_args
        terraform_cmd.append('-no-color')
        calls.append(mock.call(' '.join(terraform_cmd)))

    assert main(args) == 1

    subprocess_run.assert_called()
    subprocess_run.assert_has_calls(calls)
    assert not any('apply' in name[0] for name, args in subprocess_run.call_args_list), 'Unexpected terraform apply call'


@mock.patch("lib.process_manager.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_logs(subprocess_run, terraform_cmd_args, args_helper, config_yaml_sample, tmpdir):
    """
    Command terraform create one log file for each command:
     - terraform.{cmd}.log.txt
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, *_ = args_helper(provider, conf)
    args.append('terraform')
    subprocess_run.return_value = (0, ['This is the terraform output', 'Two lines of that'])

    assert main(args) == 0

    cmd = terraform_cmd_args.split()[0]
    assert os.path.isfile(f"terraform.{cmd}.log.txt")


@mock.patch("lib.process_manager.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_logs_content(subprocess_run, terraform_cmd_args, args_helper, config_yaml_sample, tmpdir):
    """
    Each terraform log file contains terraform stdout
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, *_ = args_helper(provider, conf)
    args.append('terraform')
    terraform_output = ['This is the terraform output', 'Two lines of that']
    subprocess_run.return_value = (0, terraform_output)

    assert main(args) == 0

    cmd = terraform_cmd_args.split()[0]
    with open(f"terraform.{cmd}.log.txt", 'r', encoding='utf-8') as log_file:
        log_lines = log_file.read().splitlines()
    assert terraform_output == log_lines


@mock.patch("lib.process_manager.subprocess_run")
@pytest.mark.parametrize("terraform_cmd_args", terraform_cmds)
def test_terraform_call_custom_bin(subprocess_run, terraform_cmd_args, args_helper):
    """
    Check that terraform commandslike:
     - 'terraform init'
     - 'terraform plan'
     - 'terraform apply'

    are composed with the custom binary file specified in the conf.yaml
    """
    provider = 'mangiafuoco'
    conf = """---
apiver: 3
provider: mangiafuoco
terraform:
  bin: one_special_terraform_exe
  variables:
    az_region: "westeurope"
    """
    args, terraform_dir, *_ = args_helper(provider, conf)
    args.append('terraform')
    subprocess_run.return_value = (0, [])
    assert main(args) == 0
    subprocess_run.assert_called()

    calls = []
    calls.append(mock.call(f"one_special_terraform_exe -chdir={terraform_dir} {terraform_cmd_args} -no-color"))

    subprocess_run.assert_has_calls(calls)


@pytest.mark.skip(reason="Run a true deployment")
@pytest.mark.parametrize("terraform_cmd_args", [('init')])
def test_integration_terraform(terraform_cmd_args, config_yaml_sample, tmpdir):
    """
    Run a test with the true Terraform
    """
    provider = 'azure'
    conf = config_yaml_sample(provider)
    config_file_name = 'config.yaml'
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(conf)
    args = [
        '--verbose',
        '--base-dir',
        str(os.path.abspath(os.path.join(os.getcwd(), '..', '..'))),
        '--config-file',
        config_file_name,
        'terraform'
    ]

    assert main(args) == 0

    if isinstance(terraform_cmd_args, str):
        cmd = terraform_cmd_args
    else:
        cmd = terraform_cmd_args[0]

    with open(f"terraform.{cmd}.log.txt", 'r', encoding='utf-8') as log_file:
        log_lines = log_file.readlines()
    assert 'Initializing modules...\n' in log_lines


@mock.patch("lib.process_manager.subprocess_run")
def test_terraform_dryrun(subprocess_run, args_helper, config_yaml_sample):
    """
    Command terraform does not call terraform executable in dryrun mode
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, *_ = args_helper(provider, conf)
    args.append('terraform')
    args.insert(0, '--dryrun')
    subprocess_run.return_value = (0, [])

    assert main(args) == 0

    subprocess_run.assert_not_called()


@mock.patch("lib.process_manager.subprocess_run")
def test_terraform_call_terraform_destroy(subprocess_run, args_helper, config_yaml_sample):
    """
    Command terraform with -d calls 'terraform destroy'
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, *_ = args_helper(provider, conf)

    args.extend(['terraform', '-d'])

    subprocess_run.return_value = (0, [])
    calls = []
    calls.append(mock.call(f"terraform -chdir={terraform_dir} destroy -auto-approve -no-color"))

    assert main(args) == 0
    subprocess_run.assert_called()
    subprocess_run.assert_has_calls(calls)


@mock.patch("lib.process_manager.subprocess_run")
def test_terraform_call_terraform_workspace(subprocess_run, args_helper, config_yaml_sample):
    """
    Command terraform calls 'terraform workspace' if -w is used
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, *_ = args_helper(provider, conf)
    args.extend(['terraform', '-w', 'lucignolo'])
    subprocess_run.return_value = (0, [])
    assert main(args) == 0
    subprocess_run.assert_called()

    calls = []
    calls.append(mock.call(f"terraform -chdir={terraform_dir} workspace new lucignolo -no-color"))

    subprocess_run.assert_has_calls(calls)


@mock.patch("lib.process_manager.subprocess_run")
def test_terraform_call_terraform_workspace_destroy(subprocess_run, args_helper, config_yaml_sample):
    """
    Command terraform calls 'terraform workspace' if -w is used
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, *_ = args_helper(provider, conf)
    args.extend(['terraform', '-w', 'lucignolo', '-d'])
    subprocess_run.return_value = (0, [])
    assert main(args) == 0
    subprocess_run.assert_called()

    calls = []
    calls.append(mock.call(f"terraform -chdir={terraform_dir} workspace select default -no-color"))
    calls.append(mock.call(f"terraform -chdir={terraform_dir} workspace delete lucignolo -no-color"))

    subprocess_run.assert_has_calls(calls)


@mock.patch("lib.process_manager.subprocess_run")
def test_terraform_call_terraform_parallel(subprocess_run, args_helper, config_yaml_sample):
    """
    Command terraform calls 'terraform plan' and 'terraform apply' with -parallelism=n
    """
    provider = 'mangiafuoco'
    conf = config_yaml_sample(provider)

    args, terraform_dir, *_ = args_helper(provider, conf)
    args.extend(['terraform', '-p', '5'])
    subprocess_run.return_value = (0, [])
    assert main(args) == 0
    subprocess_run.assert_called()

    calls = []
    calls.append(mock.call(f"terraform -chdir={terraform_dir} plan -parallelism=5 -out=plan.zip -no-color"))
    calls.append(mock.call(f"terraform -chdir={terraform_dir} apply -parallelism=5 -auto-approve plan.zip -no-color"))

    subprocess_run.assert_has_calls(calls)
