from unittest import mock
import logging
log = logging.getLogger(__name__)


from qesap import main


def test_terraform(base_args, tmpdir):
    """
    Test the most common and simple execution of terraform:
     - ...
    """
    args = base_args(tmpdir)
    args.append('terraform')
    assert main(args) == 0


@mock.patch("qesap.subprocess_run")
def test_terraform_call_terraform(run, args_helper):
    provider = 'mangiafuoco'
    conf = f"""---
terraform:
  provider: {provider}
"""
    args, terraform_dir, _, _ = args_helper(provider, conf, '')
    args.append('terraform')
    log.error(args)
    run.return_value = (0, [])
    assert main(args) == 0
    run.assert_called()

    calls = []
    calls.append(mock.call(['TF_LOG_PATH=terraform.init.log.txt', 'TF_LOG=INFO', 'terraform', f"-chdir=\"{terraform_dir}\"", 'init', '-no-color']))
    calls.append(mock.call(['TF_LOG_PATH=terraform.plan.log.txt TF_LOG=INFO terraform -chdir="${TerraformPath}" plan -out=plan.zip -no-color']))
    calls.append(mock.call(['TF_LOG_PATH=terraform.apply.log.txt TF_LOG=INFO terraform -chdir="${TerraformPath}" apply -auto-approve plan.zip -no-color']))

    run.assert_has_calls(calls)
