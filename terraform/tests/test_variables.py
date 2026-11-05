import os
import re
import pytest
import tftest

ALL = ['aws', 'azure', 'gcp']

# Variables without a default value, for each CSP.
# The tests set them to a dummy string. Add new required variables here.
REQUIRED_VARS = {
    'aws': ['aws_region', 'public_key', 'os_image'],
    'azure': ['public_key'],
    'gcp': ['project', 'region', 'gcp_credentials_file', 'public_key', 'os_image'],
}

IP_ERROR = 'Invalid IP address format.'
CIDR_ERROR = 'Must be a valid IPv4 CIDR block address.'
RANGE_ERROR = 'Invalid IP range format.'


class Variables:
    """
    Run plan on the variables.tf copy of one CSP
    to check if a variable value passes the validation.
    """

    def __init__(self, tf, csp):
        self.tf = tf
        self.csp = csp

    def plan(self, **tf_vars):
        required = {name: 'dummy' for name in REQUIRED_VARS[self.csp]}
        return self.tf.plan(tf_vars={**required, **tf_vars})

    def valid(self, name, value):
        self.plan(**{name: value})

    def invalid(self, name, value, message):
        with pytest.raises(tftest.TerraformTestError) as excinfo:
            self.plan(**{name: value})
        # Terraform puts diagnostics in a box and wraps long lines
        error = ' '.join(excinfo.value.args[0].replace('│', ' ').split())
        assert message in error


@pytest.fixture
def variables(variables_module, csp):
    """
    Variables of the CSP from the 'csp' parameter of the test
    """
    return Variables(variables_module(csp), csp)


@pytest.mark.parametrize('csp', ALL)
def test_defaults(variables):
    """
    The default values of all the variables must pass the validation
    """
    variables.plan()


@pytest.mark.parametrize('csp', ALL)
def test_all_validations_have_a_test(fixtures_dir, csp):
    """
    Each variable with a validation block must have a test
    named test_<variable> or test_<csp>_<variable>
    """
    with open(os.path.join(fixtures_dir, csp, 'variables.tf'), encoding='utf-8') as f:
        content = f.read()
    # terraform fmt puts the '}' that closes a variable block at the start of a line
    blocks = re.findall(r'^variable "([^"]+)" \{(.*?)^\}$', content, re.MULTILINE | re.DOTALL)
    validated = [name for name, body in blocks if re.search(r'^\s*validation\s*\{', body, re.MULTILINE)]
    tests = [name for name in globals() if name.startswith('test_')]
    missing = [
        var for var in validated
        if f"test_{var}" not in tests
        and not any(t == f"test_{csp}_{var}" or t.startswith(f"test_{csp}_{var}_") for t in tests)
    ]
    assert missing == [], f"Variables in {csp}/variables.tf with validation and no test"


# Variables with the same validation in all the CSPs that validate them
@pytest.mark.parametrize('csp', ALL)
def test_deployment_name(variables):
    variables.valid('deployment_name', '')
    variables.valid('deployment_name', 'mytest')
    variables.invalid('deployment_name', 'default', 'Invalid deployment_name (default) .')


@pytest.mark.parametrize('csp', ALL)
def test_iscsi_count(variables):
    variables.valid('iscsi_count', 1)
    variables.valid('iscsi_count', 3)
    variables.invalid('iscsi_count', 0, 'The number of iscsi server must be 1, 2 or 3.')
    variables.invalid('iscsi_count', 4, 'The number of iscsi server must be 1, 2 or 3.')


@pytest.mark.parametrize('csp', ALL)
def test_sbd_storage_type(variables):
    variables.valid('sbd_storage_type', 'iscsi')
    variables.invalid('sbd_storage_type', 'nfs', 'Invalid SBD storage type. Options: iscsi .')
    variables.invalid('sbd_storage_type', '', 'Invalid SBD storage type. Options: iscsi .')


@pytest.mark.parametrize('csp', ALL)
def test_hana_cluster_fencing_mechanism(variables):
    variables.valid('hana_cluster_fencing_mechanism', 'sbd')
    variables.valid('hana_cluster_fencing_mechanism', 'native')
    variables.invalid('hana_cluster_fencing_mechanism', 'stonith', 'Invalid HANA cluster fencing mechanism.')
    variables.invalid('hana_cluster_fencing_mechanism', '', 'Invalid HANA cluster fencing mechanism.')


@pytest.mark.parametrize('csp', ALL)
def test_drbd_cluster_fencing_mechanism(variables):
    variables.valid('drbd_cluster_fencing_mechanism', 'sbd')
    variables.valid('drbd_cluster_fencing_mechanism', 'native')
    variables.invalid('drbd_cluster_fencing_mechanism', 'stonith', 'Invalid DRBD cluster fencing mechanism.')
    variables.invalid('drbd_cluster_fencing_mechanism', '', 'Invalid DRBD cluster fencing mechanism.')


@pytest.mark.parametrize('csp', ALL)
def test_netweaver_cluster_fencing_mechanism(variables):
    variables.valid('netweaver_cluster_fencing_mechanism', 'sbd')
    variables.valid('netweaver_cluster_fencing_mechanism', 'native')
    variables.invalid('netweaver_cluster_fencing_mechanism', 'stonith', 'Invalid Netweaver cluster fencing mechanism.')
    variables.invalid('netweaver_cluster_fencing_mechanism', '', 'Invalid Netweaver cluster fencing mechanism.')


@pytest.mark.parametrize('csp', ALL)
def test_allowed_ssh_cidr_csv(variables):
    error = 'The value must be a valid CIDR or a comma-separated list of valid CIDRs.'
    variables.valid('allowed_ssh_cidr_csv', '')
    variables.valid('allowed_ssh_cidr_csv', '10.0.0.0/8')
    variables.valid('allowed_ssh_cidr_csv', '10.0.0.0/8, 192.168.1.0/24')
    variables.invalid('allowed_ssh_cidr_csv', '10.0.0.1', error)
    variables.invalid('allowed_ssh_cidr_csv', '10.0.0.0/8,not-a-cidr', error)


@pytest.mark.parametrize('csp', ['azure', 'gcp'])
def test_admin_user(variables):
    variables.valid('admin_user', 'cloudadmin')
    variables.invalid('admin_user', 'admin', "The value 'admin' cannot be used for admin_user")


@pytest.mark.parametrize('csp', ALL)
def test_hana_cluster_vip(variables):
    variables.valid('hana_cluster_vip', '')
    variables.valid('hana_cluster_vip', '10.0.0.1')
    variables.invalid('hana_cluster_vip', '10.0.0', IP_ERROR)
    variables.invalid('hana_cluster_vip', 'not-an-ip', IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_hana_cluster_vip_secondary(variables):
    variables.valid('hana_cluster_vip_secondary', '')
    variables.valid('hana_cluster_vip_secondary', '10.0.0.1')
    variables.invalid('hana_cluster_vip_secondary', '10.0.0', IP_ERROR)
    variables.invalid('hana_cluster_vip_secondary', 'not-an-ip', IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_drbd_cluster_vip(variables):
    variables.valid('drbd_cluster_vip', '')
    variables.valid('drbd_cluster_vip', '10.0.0.1')
    variables.invalid('drbd_cluster_vip', '10.0.0', IP_ERROR)
    variables.invalid('drbd_cluster_vip', 'not-an-ip', IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_monitoring_srv_ip(variables):
    variables.valid('monitoring_srv_ip', '')
    variables.valid('monitoring_srv_ip', '10.0.0.1')
    variables.invalid('monitoring_srv_ip', '10.0.0', IP_ERROR)
    variables.invalid('monitoring_srv_ip', 'not-an-ip', IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_hana_ips(variables):
    variables.valid('hana_ips', [])
    variables.valid('hana_ips', ['10.0.0.1', '10.0.0.2'])
    variables.invalid('hana_ips', ['10.0.0.1', '10.0.0'], IP_ERROR)
    variables.invalid('hana_ips', ['not-an-ip'], IP_ERROR)


@pytest.mark.parametrize('csp', ['aws', 'gcp'])
def test_drbd_ips(variables):
    variables.valid('drbd_ips', [])
    variables.valid('drbd_ips', ['10.0.0.1', '10.0.0.2'])
    variables.invalid('drbd_ips', ['10.0.0.1', '10.0.0'], IP_ERROR)
    variables.invalid('drbd_ips', ['not-an-ip'], IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_iscsi_ips(variables):
    variables.valid('iscsi_ips', [])
    variables.valid('iscsi_ips', ['10.0.0.1', '10.0.0.2'])
    variables.invalid('iscsi_ips', ['10.0.0.1', '10.0.0'], IP_ERROR)
    variables.invalid('iscsi_ips', ['not-an-ip'], IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_netweaver_ips(variables):
    variables.valid('netweaver_ips', [])
    variables.valid('netweaver_ips', ['10.0.0.1', '10.0.0.2'])
    variables.invalid('netweaver_ips', ['10.0.0.1', '10.0.0'], IP_ERROR)
    variables.invalid('netweaver_ips', ['not-an-ip'], IP_ERROR)


@pytest.mark.parametrize('csp', ALL)
def test_netweaver_virtual_ips(variables):
    variables.valid('netweaver_virtual_ips', [])
    variables.valid('netweaver_virtual_ips', ['10.0.0.1', '10.0.0.2'])
    variables.invalid('netweaver_virtual_ips', ['10.0.0.1', '10.0.0'], IP_ERROR)
    variables.invalid('netweaver_virtual_ips', ['not-an-ip'], IP_ERROR)


# AWS

@pytest.mark.parametrize('csp', ['aws'])
def test_aws_vpc_address_range(variables):
    variables.valid('vpc_address_range', '10.0.0.0/16')
    variables.invalid('vpc_address_range', '10.0.0.0', CIDR_ERROR)
    variables.invalid('vpc_address_range', 'not-a-cidr', CIDR_ERROR)


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_virtual_address_range(variables):
    variables.valid('virtual_address_range', '192.168.1.0/24')
    variables.invalid('virtual_address_range', '192.168.1.0', RANGE_ERROR)
    variables.invalid('virtual_address_range', 'not-a-cidr', RANGE_ERROR)


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_hana_scale_out_shared_storage_type(variables):
    variables.valid('hana_scale_out_shared_storage_type', '')
    variables.invalid('hana_scale_out_shared_storage_type', 'anf', 'Invalid HANA scale out storage type.')


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_netweaver_shared_storage_type(variables):
    variables.valid('netweaver_shared_storage_type', 'drbd')
    variables.valid('netweaver_shared_storage_type', 'efs')
    variables.invalid('netweaver_shared_storage_type', '', 'Invalid Netweaver shared storage type.')
    variables.invalid('netweaver_shared_storage_type', 'anf', 'Invalid Netweaver shared storage type.')


@pytest.mark.parametrize('tags', [
    {},
    {'openqa_created_date': '2026-01-01T00:00:00', 'openqa_var_job_id': '123'},
    {'a/b@c': 'x+y=z-_:.'},
    {'key': ''},
], ids=['empty', 'openqa', 'special_chars', 'empty_value'])
@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_valid(variables, tags):
    variables.valid('custom_tags', tags)


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_count(variables):
    """
    AWS accepts 50 tags at most. The deployment adds the 'workspace' tag.
    """
    tags = {f"key{i}": 'value' for i in range(49)}
    variables.valid('custom_tags', tags)
    variables.valid('custom_tags', {'workspace': 'w', **tags})
    variables.invalid('custom_tags', {'key49': 'value', **tags}, 'Too many tags')


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_key_length(variables):
    error = 'Tag keys must be 1 to 128 characters long'
    variables.valid('custom_tags', {'a' * 128: 'ok'})
    variables.invalid('custom_tags', {'a' * 129: 'ok'}, error)
    variables.invalid('custom_tags', {'': 'ok'}, error)


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_key_aws_prefix(variables):
    variables.invalid('custom_tags', {'aws:reserved': 'v'}, "Tag keys must not use the reserved 'aws:' prefix")


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_value_null(variables):
    variables.invalid('custom_tags', {'key': None}, 'Tag values must not be null')


@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_value_length(variables):
    variables.valid('custom_tags', {'key': 'b' * 256})
    variables.invalid('custom_tags', {'key': 'b' * 257}, 'Tag values must be 256 characters long or less')


@pytest.mark.parametrize('tags', [
    {'key space': 'v'},
    {'key': 'a b'},
    {'key': 'a$b'},
    {'key': 'a`b'},
    {'key': 'a,b'},
    {'key': 'a{b}'},
], ids=['space_in_key', 'space', 'dollar', 'backtick', 'comma', 'braces'])
@pytest.mark.parametrize('csp', ['aws'])
def test_aws_custom_tags_invalid_chars(variables, tags):
    variables.invalid('custom_tags', tags, 'Tag keys and values can only use the characters')


# Azure

@pytest.mark.parametrize('csp', ['azure'])
def test_azure_vnet_address_range(variables):
    variables.valid('vnet_address_range', '10.74.0.0/16')
    variables.invalid('vnet_address_range', '10.74.0.0', CIDR_ERROR)
    variables.invalid('vnet_address_range', '', CIDR_ERROR)


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_subnet_address_range(variables):
    variables.valid('subnet_address_range', '')
    variables.valid('subnet_address_range', '10.74.1.0/24')
    variables.invalid('subnet_address_range', '10.74.1.0', CIDR_ERROR)


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_subnet_netapp_address_range(variables):
    variables.valid('subnet_netapp_address_range', '')
    variables.valid('subnet_netapp_address_range', '10.74.3.0/24')
    variables.invalid('subnet_netapp_address_range', '10.74.3.0', CIDR_ERROR)


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_cluster_ip(variables):
    variables.valid('cluster_ip', '')
    variables.valid('cluster_ip', '10.74.0.1')
    variables.invalid('cluster_ip', '10.74.0', IP_ERROR)


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_hana_majority_maker_ip(variables):
    variables.valid('hana_majority_maker_ip', '')
    variables.valid('hana_majority_maker_ip', '10.74.0.1')
    variables.invalid('hana_majority_maker_ip', '10.74.0', IP_ERROR)


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_iscsi_srv_ip(variables):
    variables.valid('iscsi_srv_ip', '')
    variables.valid('iscsi_srv_ip', '10.74.0.1')
    variables.invalid('iscsi_srv_ip', '10.74.0', IP_ERROR)


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_hana_scale_out_shared_storage_type(variables):
    variables.valid('hana_scale_out_shared_storage_type', '')
    variables.valid('hana_scale_out_shared_storage_type', 'anf')
    variables.invalid('hana_scale_out_shared_storage_type', 'nfs', 'Invalid HANA scale out storage type.')


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_netweaver_shared_storage_type(variables):
    variables.valid('netweaver_shared_storage_type', '')
    variables.valid('netweaver_shared_storage_type', 'drbd')
    variables.valid('netweaver_shared_storage_type', 'anf')
    variables.invalid('netweaver_shared_storage_type', 'efs', 'Invalid Netweaver shared storage type.')


@pytest.mark.parametrize('csp', ['azure'])
def test_azure_anf_pool_service_level(variables):
    for level in ['Standard', 'Premium', 'Ultra']:
        variables.valid('anf_pool_service_level', level)
    variables.invalid('anf_pool_service_level', 'Basic', 'Invalid ANF Pool service level.')
    variables.invalid('anf_pool_service_level', 'ultra', 'Invalid ANF Pool service level.')


# GCP

@pytest.mark.parametrize('csp', ['gcp'])
def test_gcp_ip_cidr_range(variables):
    variables.valid('ip_cidr_range', '10.0.0.0/24')
    variables.invalid('ip_cidr_range', '10.0.0.0', RANGE_ERROR)
    variables.invalid('ip_cidr_range', 'not-a-cidr', RANGE_ERROR)


@pytest.mark.parametrize('csp', ['gcp'])
def test_gcp_hana_scale_out_shared_storage_type(variables):
    variables.valid('hana_scale_out_shared_storage_type', '')
    variables.invalid('hana_scale_out_shared_storage_type', 'anf', 'Invalid HANA scale out storage type.')


@pytest.mark.parametrize('csp', ['gcp'])
def test_gcp_netweaver_shared_storage_type(variables):
    variables.valid('netweaver_shared_storage_type', '')
    variables.invalid('netweaver_shared_storage_type', 'drbd', 'Invalid Netweaver shared storage type.')


@pytest.mark.parametrize('csp', ['gcp'])
def test_gcp_hana_cluster_vip_mechanism(variables):
    variables.valid('hana_cluster_vip_mechanism', 'load-balancer')
    variables.valid('hana_cluster_vip_mechanism', 'route')
    variables.invalid('hana_cluster_vip_mechanism', 'dns', 'Invalid HANA cluster vip mechanism.')


@pytest.mark.parametrize('csp', ['gcp'])
def test_gcp_drbd_cluster_vip_mechanism(variables):
    variables.valid('drbd_cluster_vip_mechanism', 'load-balancer')
    variables.valid('drbd_cluster_vip_mechanism', 'route')
    variables.invalid('drbd_cluster_vip_mechanism', 'dns', 'Invalid DRBD cluster vip mechanism.')


@pytest.mark.parametrize('csp', ['gcp'])
def test_gcp_netweaver_cluster_vip_mechanism(variables):
    variables.valid('netweaver_cluster_vip_mechanism', 'load-balancer')
    variables.valid('netweaver_cluster_vip_mechanism', 'route')
    variables.invalid('netweaver_cluster_vip_mechanism', 'dns', 'Invalid Netweaver cluster vip mechanism.')
