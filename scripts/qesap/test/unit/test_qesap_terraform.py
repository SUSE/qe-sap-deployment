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
    args, _, _ = args_helper('', '', '')
    args.append('terraform')
    log.error(args)
    assert main(args) == 0
    assert run.assert_called()
