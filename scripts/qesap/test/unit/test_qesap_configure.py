import os
import re
import yaml
import logging
log = logging.getLogger(__name__)

#from unittest import mock
import pytest

from qesap import main

DATA_DIR = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'assets')

#@pytest.mark.datafiles(os.path.join(DATA_DIR,'repo'))
#def test_some(datafiles):
#    log.error(datafiles)


def test_configure(configure_helper, config_yaml_sample):
    """
    Test the most common and simple execution of configure:
     - ...
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, _, _ = configure_helper(provider, conf, [])

    assert main(args) == 0


def test_configure_apiver(configure_helper):
    '''
    The configure has to have a apiver field at top level
    '''
    provider = 'pinocchio'
    conf = f"""---
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, [])

    assert main(args) == 1

    conf = f"""---
apiver:
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, [])

    assert main(args) == 1

    conf = f"""---
apiver: chiodo
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, [])

    assert main(args) == 1


def test_configure_no_tfvars_template(args_helper, config_yaml_sample):
    '''
    if tfvars template is missing,
    just create tfvars from the config.yaml content
    '''
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)

    # Create some regexp from the injected conf.yaml
    # to be used later in the verification against the generated terraform.tfvars
    regexp_set = []
    conf_dict = yaml.safe_load(conf)
    for k, v in conf_dict['terraform']['variables'].items():
        # just focus on the strings variables
        if isinstance(v, str):
            regexp_set.append(r'{0}\s?=\s?"{1}"'.format(k,v))

    args, tfvar_path, _, _ = args_helper(provider, conf, None)
    args.append('configure')
    tfvar_file = os.path.join(tfvar_path, 'terraform.tfvars')

    assert main(args) == 0

    assert os.path.isfile(tfvar_file)
    with open(tfvar_file, 'r') as f:
        tfvars_lines = f.readlines()
        for var_re in regexp_set:
            one_match = False
            for line in tfvars_lines:
                #log.debug("Check %s", line)
                if not one_match:
                    match = re.search(var_re, line)
                    if match:
                        log.debug("Line [%s] match with [%s]", line, var_re)
                        one_match = True
            assert one_match, 'Variable:' + var_re + ' missing in the generated terraform.tfvars'


def test_configure_create_tfvars_file(configure_helper, config_yaml_sample):
    """
    Test that 'configure' write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, tfvar_file, _ = configure_helper(provider, conf, [])

    assert main(args) == 0

    assert os.path.isfile(tfvar_file)


def test_configure_tfvars_novariables_notemplate(configure_helper):
    """
    If no terraform.tfvars.template is present and
    no terraform::variables is present in the config.yaml
    it has to fails.
    """
    provider = 'pinocchio'

    conf = f"""---
apiver: 1
provider: {provider}
ansible:
    hana_urls: something"""
    args, tfvar_path, _ = configure_helper(provider, conf, None)

    assert main(args) == 1


def test_configure_tfvars_novariables(configure_helper):
    """
    Test that 'configure' generated terraform.tfvars file
    content is like terraform.tfvars.template
    if no variables are provided in the config.yaml
    """
    provider = 'pinocchio'
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]

    conf = f"""---
apiver: 1
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    with open(tfvar_path, 'r') as file:
        data = file.readlines()
        assert tfvar_template == data

    conf = f"""---
apiver: 1
provider: {provider}
ansible:
    hana_urls: something"""
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    with open(tfvar_path, 'r') as file:
        data = file.readlines()
        assert tfvar_template == data


def test_configure_tfvars_with_variables(configure_helper):
    """
    Test that 'configure' generated terraform.tfvars file
    content is like terraform.tfvars.template
    plus all key/value pairs from the variables section in
    the config.yaml
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 1
provider: {provider}
terraform:
  variables:
    region : eu1
    deployment_name : "rocket"
ansible:
    hana_urls: something"""
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24"]
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    expected_tfvars = tfvar_template[0:2]
    # EOL is expected to be added in terraform.tfvars
    # if missing at the end of the template
    expected_tfvars.append(tfvar_template[2] + '\n')
    expected_tfvars.append('region = "eu1"\n')
    expected_tfvars.append('deployment_name = "rocket"\n')
    with open(tfvar_path, 'r') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_tfvars_string_commas(configure_helper):
    """
    Terraform.tfvars need commas around all strings variables
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 1
provider: {provider}
terraform:
  variables:
    region : eu1
    deployment_name : "rocket"
    os_image: SUSE:sles-sap-15-sp3-byos:gen2:2022.05.05
    public_key: /root/secret/id_rsa.pub
ansible:
    hana_urls: something"""
    tfvar_template = ["something = static"]
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    expected_tfvars = []
    # EOL is expected to be added in terraform.tfvars
    # if missing at the end of the template
    expected_tfvars.append(tfvar_template[0] + '\n')
    expected_tfvars.append('region = "eu1"\n')
    expected_tfvars.append('deployment_name = "rocket"\n')
    expected_tfvars.append('os_image = "SUSE:sles-sap-15-sp3-byos:gen2:2022.05.05"\n')
    expected_tfvars.append('public_key = "/root/secret/id_rsa.pub"\n')
    with open(tfvar_path, 'r') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_tfvars_overwrite_variables(configure_helper):
    """
    Test 'configure' generated terraform.tfvars file:
    if same key pair is both in the terraform.tfvars.template
    and config.yaml, the YAML content win
    """
    provider = 'pinocchio'

    conf = f"""---
apiver: 1
provider: {provider}
terraform:
  variables:
    something : yamlrulez
ansible:
    hana_urls: something"""

    tfvar_template = [
    "something = static\n",
    "somethingelse = keep\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    expected_tfvars = [
    "something = yamlrulez\n",
    "somethingelse = keep\n"]
    with open(tfvar_path, 'r') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_create_ansible_vars(configure_helper, config_yaml_sample):
    """
    Test that 'configure' write an azure_hana_media.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, _, hana_vars = configure_helper(provider, conf, [])

    main(args)

    assert os.path.isfile(hana_vars)


def test_configure_ansible_vars_content(configure_helper, config_yaml_sample):
    """
    Test that 'configure' write an azure_hana_media.yaml with
    expected content
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 1
provider: {provider}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  hana_urls:
    - SAPCAR_URL
    - SAP_HANA_URL
    - SAP_CLIENT_SAR_URL"""
    args, _, hana_vars = configure_helper(provider, conf, [])
    main(args)

    with open(hana_vars, 'r') as file:
        data = yaml.load(file, Loader=yaml.FullLoader)
        assert 'hana_urls' in data.keys()
        assert len(data['hana_urls']) == 3
        assert 'SAPCAR_URL' in data['hana_urls']
        assert 'SAP_HANA_URL' in data['hana_urls']
        assert 'SAP_CLIENT_SAR_URL' in data['hana_urls']


def test_configure_dryrun(config_yaml_sample, configure_helper):
    """
    Test that 'configure' in DryRun mode
    does NOT write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    and azure_hana_media.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]
    args, tfvar_path, hana_vars = configure_helper(provider, conf, tfvar_template)
    args.insert(0, '--dryrun')

    assert 0 == main(args)

    assert not os.path.isfile(tfvar_path)
    assert not os.path.isfile(hana_vars)


def test_configure_checkfolder(base_args, tmpdir):
    """
    Test that 'configure' fails if the folder structure
    at -b is not the expected one:
     - <BASEDIR>/terraform
     - <BASEDIR>/ansible/playbooks/vars/
    """
    provider = 'pinocchio'
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""---
apiver: 1
provider: {provider}
ansible:
    hana_urls: onlyone
""")

    folder_1 = tmpdir / '1'
    os.makedirs(folder_1)
    args = base_args(base_dir=folder_1, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1

    folder_2 = tmpdir / '2'
    os.makedirs(folder_2)
    terraform_2 = folder_2 / 'terraform'
    os.makedirs(terraform_2)
    args = base_args(base_dir=folder_2, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1

    folder_3 = tmpdir / '3'
    os.makedirs(folder_3)
    terraform_3 = folder_3 / 'terraform'
    os.makedirs(terraform_3)
    cloud_3 = terraform_3 / provider
    os.makedirs(cloud_3)
    args = base_args(base_dir=folder_3, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1

    folder_4 = tmpdir / '4'
    os.makedirs(folder_4)
    terraform_4 = folder_4 / 'terraform'
    os.makedirs(terraform_4)
    cloud_4 = terraform_4 / 'Pinocchio'
    os.makedirs(cloud_4)
    with open(os.path.join(cloud_4, 'terraform.tfvars.template'), 'w') as file:
        file.write("")
    args = base_args(base_dir=folder_4, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1


def test_configure_fail_at_missing_params(configure_helper):
    """
    Test that 'configure' fails if some arguments are missing
    in the configuration file provided at -c:
     - terraform
     - terraform::provider
    """

    # test has to fail as config is empty
    args, tfvar_path, _ = configure_helper('pinocchio', "", [])
    assert main(args) == 1

    # test has to fail as config has 'terraform' but no anything else
    args, tfvar_path, _ = configure_helper('pinocchio', "terraform:", [])
    assert main(args) == 1

    conf = """---
apiver: 1
provider:
terraform:
ansible:"""
    args, tfvar_path, _ = configure_helper('pinocchio', conf, [])
    assert main(args) == 1

    conf = """---
apiver: 1
provider: something
terraform:    
ansible:"""
    args, tfvar_path, _ = configure_helper('pinocchio', conf, [])
    assert main(args) == 1


def test_configure_check_terraform_cloud_provider(base_args, tmpdir):
    """
    Test that 'configure' fails if the folder structure
    at -b is not the expected one:
     - <BASEDIR>/terraform/<CLOUD_PROVIDER> with CLOUD_PROVIDER from the config.yaml
    """
    provider = 'pinocchio'

    # create the <BASEDIR>/terraform but not the 
    # <BASEDIR>/terraform/pinocchio
    os.makedirs(os.path.join(tmpdir,'terraform'))
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""---
apiver: 1
provider: {provider}
ansible:
    hana_urls: onlyone
""")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1
