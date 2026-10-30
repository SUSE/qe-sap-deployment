import os
import shutil
import pytest
import tftest


def pytest_report_header():
    return f"tftest binary: {os.environ.get('TFTEST_BINARY', 'terraform')}"


@pytest.fixture(scope='session')
def fixtures_dir():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


@pytest.fixture(scope='session')
def tf_binary():
    """
    Binary that runs the tests: terraform (default) or tofu.
    Set the TFTEST_BINARY environment variable to use an other binary.
    The value can be a command in PATH or a full path.
    """
    return os.environ.get('TFTEST_BINARY', 'terraform')


@pytest.fixture(scope='session')
def variables_module(tmp_path_factory, fixtures_dir, tf_binary):
    """
    Return a function that copies the variables.tf file of a CSP folder
    to a temporary folder and runs init there. The function returns
    the TerraformTest object of the temporary folder.

    Use it to test the variable validation with a plan.
    The temporary module has no providers and no resources,
    so the plan does not need network access or cloud credentials.
    """
    modules = {}

    def _create(csp):
        if csp not in modules:
            tfdir = tmp_path_factory.mktemp(f"{csp}_variables")
            shutil.copy(os.path.join(fixtures_dir, csp, 'variables.tf'), tfdir)
            tf = tftest.TerraformTest(str(tfdir), binary=tf_binary)
            tf.init()
            modules[csp] = tf
        return modules[csp]
    return _create
