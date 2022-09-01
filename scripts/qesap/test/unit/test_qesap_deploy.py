from qesap import main


def test_deploy(base_args, tmpdir):
    """
    Test the most common and simple execution of deploy:
     - ...
    """
    args = base_args(tmpdir)
    args.append('deploy')
    assert main(args) == 0
