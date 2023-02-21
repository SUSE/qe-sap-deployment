from qesap import main
import pytest


@pytest.mark.skip(reason="Code not ready")
def test_destroy(base_args, tmpdir):
    """
    Test the most common and simple execution of destroy:
     - ...
    """
    args = base_args(tmpdir)
    args.append('destroy')
    assert main(args) == 0
