import os
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


def test_configure(configure_helper):
    """
    Test the most common and simple execution of configure:
     - ...
    """
    provider = 'pinocchio'
    conf = f"""---
terraform:
  provider: {provider}"""
    args, _, _ = configure_helper(provider, conf, [])

    assert main(args) == 0


def test_configure_create_tfvars_file(configure_helper):
    """
    Test that 'configure' write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    """
    provider = 'pinocchio'
    conf = f"""---
terraform:
  provider: {provider}"""
    args, tfvar_path, _ = configure_helper(provider, conf, [])

    main(args)

    assert os.path.isfile(tfvar_path)


def test_configure_tfvars_novariables(configure_helper):
    """
    Test that 'configure' generated terraform.tfvars file
    content is like terraform.tfvars.template
    if no variables are provided in the config.yaml
    """
    provider = 'pinocchio'
    conf = f"""---
terraform:
  provider: {provider}"""
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    main(args)

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
terraform:
  provider: {provider}
  variables:
    region : eu1
    deployment_name : rocket"""
    tfvar_template = [
    "something = static\n",
    "hananame = hahaha\n",
    "ip_range = 10.0.4.0/24\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    main(args)

    expected_tfvars = tfvar_template
    expected_tfvars.append("region = eu1\n")
    expected_tfvars.append("deployment_name = rocket\n")
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
terraform:
  provider: {provider}
  variables:
    something : yamlrulez"""

    tfvar_template = [
    "something = static\n",
    "somethingelse = keep\n"]
    args, tfvar_path, _ = configure_helper(provider, conf, tfvar_template)

    main(args)

    expected_tfvars = [
    "something = yamlrulez\n",
    "somethingelse = keep\n"]
    with open(tfvar_path, 'r') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_create_ansible_vars(configure_helper):
    """
    Test that 'configure' write an azure_hana_media.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    conf = f"""---
terraform:
  provider: {provider}"""
    args, _, hana_vars = configure_helper(provider, conf, [])

    main(args)

    assert os.path.isfile(hana_vars)


def test_configure_ansible_vars_content(configure_helper):
    """
    Test that 'configure' write an azure_hana_media.yaml with
    expected content
    """
    provider = 'pinocchio'
    conf = f"""---
terraform:
  provider: {provider}
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


def test_configure_dryrun(configure_helper):
    """
    Test that 'configure' in DryRun mode
    does NOT write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    and azure_hana_media.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    conf = f"""---
terraform:
  provider: {provider}"""
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
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:
  provider: Pinocchio""")

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
    cloud_3 = terraform_3 / 'Pinocchio'
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
        file.write(f"""terraform:
  provider: {provider}""")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1


def test_configure_tfvarstemplate(base_args, tmpdir):
    """
    Test that 'configure' fails if
    <BASE_DIR>/terraform/<PROVIDER>/terraform.tfvars.template
    is missing
    """
    provider = 'pinocchio'
    os.makedirs(os.path.join(tmpdir,'terraform', provider))
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:
  provider: {provider}""")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1