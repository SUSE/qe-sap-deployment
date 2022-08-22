from unittest import mock
import logging
log = logging.getLogger(__name__)


from qesap import main


@mock.patch("qesap.subprocess_run")
def test_terraform_call_terraform_init(run, args_helper):
    """
    Command terraform calls 'terraform init'
    """
    provider = 'mangiafuoco'
    conf = f"""---
terraform:
  provider: {provider}
ansible:
    hana_urls: onlyone"""

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()

    calls = []
    calls.append(mock.call([
        'TF_LOG_PATH=terraform.init.log.txt',
        'TF_LOG=INFO',
        'terraform',
        f"-chdir=\"{terraform_dir}\"",
        'init',
        '-no-color']))

    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_terraform_call_terraform_plan(run, args_helper):
    """
    Command terraform calls 'terraform plan'
    """
    provider = 'mangiafuoco'
    conf = f"""---
terraform:
  provider: {provider}
ansible:
    hana_urls: onlyone"""

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()

    calls = []
    calls.append(mock.call([
        'TF_LOG_PATH=terraform.plan.log.txt',
        'TF_LOG=INFO',
        'terraform',
        f"-chdir=\"{terraform_dir}\"",
        'plan',
        '-out=plan.zip',
        '-no-color']))

    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_terraform_call_terraform_apply(run, args_helper):
    """
    Command terraform calls 'terraform apply'
    """
    provider = 'mangiafuoco'
    conf = f"""---
terraform:
  provider: {provider}
ansible:
    hana_urls: onlyone"""

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()

    calls = []
    calls.append(mock.call([
        'TF_LOG_PATH=terraform.apply.log.txt',
        'TF_LOG=INFO',
        'terraform',
        f"-chdir=\"{terraform_dir}\"",
        'apply',
        '-auto-approve',
        'plan.zip',
        '-no-color']))

    run.assert_has_calls(calls)


@mock.patch("qesap.subprocess_run")
def test_terraform_dryrun(run, args_helper):
    """
    Command terraform does not call terraform executable in dryrun mode
    """
    provider = 'mangiafuoco'
    conf = f"""---
terraform:
  provider: {provider}
ansible:
    hana_urls: onlyone"""

    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    args.insert(0, '--dryrun')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0

    run.assert_not_called()


@mock.patch("qesap.subprocess_run")
def test_terraform_call_terraform_destroy(run, args_helper):
    """
    Command terraform with -d calls 'terraform destroy'
    """
    provider = 'mangiafuoco'
    conf = f"""---
terraform:
  provider: {provider}
ansible:
    hana_urls: onlyone"""

    args, terraform_dir, _, _ = args_helper(provider, conf, '')

    args.append('terraform')
    args.append('-d')
    log.error(args)



    run.return_value = (0, [])
    calls = []
    calls.append(mock.call([
        'TF_LOG_PATH=terraform.destroy.log.txt',
        'TF_LOG=INFO',
        'terraform',
        f"-chdir=\"{terraform_dir}\"",
        'destroy',
        '-auto-approve',
        '-no-color']))

    assert main(args) == 0
    run.assert_called()


    run.assert_has_calls(calls)