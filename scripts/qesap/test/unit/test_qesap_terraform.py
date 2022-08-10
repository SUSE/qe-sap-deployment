from unittest import mock

from qesap import main


def test_terraform(base_args, tmpdir):
    """
    Test the most common and simple execution of terraform:
     - ...
    """
    args = base_args(tmpdir)
    args.append('terraform')
    assert main(args) == 0