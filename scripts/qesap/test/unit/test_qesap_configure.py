import os

from qesap import main


def test_configure(configure_helper, config_yaml_sample):
    """
    Test the most common and simple execution of configure:
     - ...
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, *_ = configure_helper(provider, conf)

    assert main(args) == 0


def test_configure_apiver(configure_helper):
    '''
    The configure has to have an apiver field at top level
    '''
    provider = 'pinocchio'
    conf = f"""---
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    args, *_ = configure_helper(provider, conf)

    assert main(args) == 1

    conf = f"""---
apiver:
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    args, *_ = configure_helper(provider, conf)

    assert main(args) == 1

    conf = f"""---
apiver: chiodo
provider: {provider}
terraform:
ansible:
    hana_urls: something"""
    args, *_ = configure_helper(provider, conf)

    assert main(args) == 1


def test_configure_dryrun(config_yaml_sample, configure_helper, tmpdir):
    """
    Test that 'configure' in DryRun mode
    does NOT write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    and hana_media.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = [
        "something = static\n",
        "hananame = hahaha\n",
        "ip_range = 10.0.4.0/24\n"]
    conf = config_yaml_sample(provider=provider, template_file=tfvar_template['file'])
    args, tfvar_path, hana_media, hana_vars = configure_helper(provider, conf, tfvar_template)
    args.insert(0, '--dryrun')

    assert 0 == main(args)

    assert not os.path.isfile(tfvar_path)
    assert not os.path.isfile(hana_media)
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
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(f"""---
apiver: 3
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
    with open(os.path.join(cloud_4, 'terraform.tfvars.template'), 'w', encoding='utf-8') as file:
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
    args, *_ = configure_helper('pinocchio', "")
    assert main(args) == 1

    # test has to fail as config has 'terraform' but no anything else
    args, *_ = configure_helper('pinocchio', "terraform:")
    assert main(args) == 1

    conf = """---
apiver: 3
provider:
terraform:
ansible:"""
    args, *_ = configure_helper('pinocchio', conf)
    assert main(args) == 1

    conf = """---
apiver: 3
provider: something
terraform:
ansible:"""
    args, *_ = configure_helper('pinocchio', conf)
    assert main(args) == 1


def test_configure_check_terraform_cloud_provider(base_args, tmpdir):
    """
    Test that 'configure' fails if the folder structure
    at -b is not the expected one within terraform:
     - <BASEDIR>/terraform/<CLOUD_PROVIDER> with CLOUD_PROVIDER from the config.yaml
    """
    provider = 'pinocchio'

    # create the <BASEDIR>/terraform but not the
    # <BASEDIR>/terraform/pinocchio
    os.makedirs(os.path.join(tmpdir, 'terraform'))
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(f"""---
apiver: 3
provider: {provider}
ansible:
    hana_urls: onlyone
""")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1


def test_configure_without_ansible(base_args, tmpdir):
    config = """---
apiver: 3
provider: pinocchio
terraform:
  variables:
    az_region: "westeurope"
    hana_ips: ["10.0.0.2", "10.0.0.3"]
    hana_data_disks_configuration:
      disk_type: "hdd,hdd,hdd"
      disks_size: "64,64,64"
"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config)
    os.makedirs(os.path.join(tmpdir, 'terraform', 'pinocchio'))

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 0


def test_configure_apiver_older_than_3(base_args, tmpdir):
    '''
       Test is using the no more supported apiver:2
       so the configure has just to fail.
    '''
    config = """---
apiver: 2
provider: pinocchio
terraform:
  variables:
    az_region: "westeurope"
    hana_ips: ["10.0.0.2", "10.0.0.3"]
    hana_data_disks_configuration:
      disk_type: "hdd,hdd,hdd"
      disks_size: "64,64,64"
ansible: pippo
"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config)
    os.makedirs(os.path.join(tmpdir, 'terraform', 'pinocchio'))
    os.makedirs(os.path.join(tmpdir, 'ansible', 'playbooks', 'vars'))

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1


def test_configure_apiver_older_than_3_no_ansible(base_args, tmpdir):
    '''
       Test is using the no more supported apiver:2
       but it also does not have the ansible section at all
       that is the only impacted one.
       Allow this conf.yaml with old apiver in this case.
    '''
    config = """---
apiver: 2
provider: pinocchio
terraform:
  variables:
    az_region: "westeurope"
    hana_ips: ["10.0.0.2", "10.0.0.3"]
    hana_data_disks_configuration:
      disk_type: "hdd,hdd,hdd"
      disks_size: "64,64,64"
"""
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write(config)
    os.makedirs(os.path.join(tmpdir, 'terraform', 'pinocchio'))

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 0
