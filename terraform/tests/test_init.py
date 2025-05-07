import pytest
import tftest


@pytest.mark.parametrize("csp", ['azure', 'aws', 'gcp'])
def test_init(fixtures_dir, csp):
    tf = tftest.TerraformTest(csp, fixtures_dir)
    init_out = tf.init(output=True)
    assert 'Terraform has been successfully initialized' in init_out
