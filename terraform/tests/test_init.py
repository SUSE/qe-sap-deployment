import pytest
import tftest


@pytest.fixture(params=['azure', 'aws', 'gcp'])
def tf(request, fixtures_dir, tf_binary):
    return tftest.TerraformTest(request.param, fixtures_dir, binary=tf_binary)


def test_init(tf):
    init_out = tf.init(output=True)
    # Terraform and OpenTofu print a different product name before this text
    assert 'has been successfully initialized' in init_out


def test_validate(tf):
    tf.init()
    validate_out = tf.execute_command('validate', '-no-color').out
    assert 'The configuration is valid' in validate_out
