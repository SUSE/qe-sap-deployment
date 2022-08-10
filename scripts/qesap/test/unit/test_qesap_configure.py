import os
from unittest import mock

from qesap import main


def test_configure(base_args, tmpdir):
    """
    Test the most common and simple execution of configure:
     - ...
    """
    args = base_args(tmpdir)
    args.append('configure')
    assert main(args) == 0


def test_configure_dryrun_has_no_run(base_args, tmpdir):
    '''
    --dryrun mode has not to call subprocess.run at all
    '''

    no_run = False
    with mock.patch('subprocess.run') as patched_run:
        args = base_args(tmpdir)
        args.append('configure')
        args.insert(0, '--dryrun')
        main(args)
        no_run = not patched_run.called
    assert no_run