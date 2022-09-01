from qesap import main


def test_ansible(base_args, tmpdir):
    """
    Test the most common and simple execution of ansible:
     - ...
    """
    args = base_args(tmpdir)
    args.append('ansible')
    assert main(args) == 0
