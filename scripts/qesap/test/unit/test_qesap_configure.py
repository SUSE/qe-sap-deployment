import os
import logging
log = logging.getLogger(__name__)

from unittest import mock

from qesap import main


def test_configure(base_args, tmpdir):
    """
    Test the most common and simple execution of configure:
     - ...
    """
    provider = 'pinocchio'
    provider_path = os.path.join(tmpdir,'terraform', provider)
    os.makedirs(provider_path)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:
  provider: {provider}""")
    with open(os.path.join(provider_path, 'terraform.tfvars.template'), 'w') as file:
        file.write("")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 0


def test_configure_writetfvars(base_args, tmpdir):
    """
    Test configure has to write a terraform.tfvars file in 
    <BASE_DIR>/terraform/<PROVIDER>
    """
    provider = 'pinocchio'
    provider_path = os.path.join(tmpdir,'terraform', provider)
    tfvar_path = os.path.join(provider_path,'terraform.tfvars')

    os.makedirs(provider_path)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:
  provider: {provider}""")
    with open(os.path.join(provider_path, 'terraform.tfvars.template'), 'w') as file:
        file.write("")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    main(args)
    assert os.path.isfile(tfvar_path)


def test_configure_tfvarscontent(base_args, tmpdir):
    """
    Test configure generated terraform.tfvars file
    has in it ...
    """
    provider = 'pinocchio'
    region = 'PaeseDeiBalocchi'
    provider_path = os.path.join(tmpdir,'terraform', provider)
    tfvar_path = os.path.join(provider_path,'terraform.tfvars')

    os.makedirs(provider_path)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:
  provider: {provider}
  region : {region}""")

    # write a temp- region : eu1late with only one variable '$region'
    with open(os.path.join(provider_path, 'terraform.tfvars.template'), 'w') as file:
        file.write("region = $region")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    main(args)
    with open(tfvar_path, 'r') as file:
        data = file.readline()
        log.error("-->%s", data)
        assert region in data


def test_configure_writetfvars_dryrun(base_args, tmpdir):
    """
    Test configure in DryRun mode
    has NOT to write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    """
    provider = 'pinocchio'
    provider_path = os.path.join(tmpdir,'terraform', provider)
    tfvar_path = os.path.join(provider_path,'terraform.tfvars')

    os.makedirs(provider_path)
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:
  provider: {provider}""")

    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    args.insert(0, '--dryrun')
    main(args)
    assert not os.path.isfile(tfvar_path)


def test_configure_checkfolder(base_args):
    """
    Configure has to fails if the folder structure
    at -b is not the expected one:
     - <BASEDIR>/terraform
    """
    args = base_args()
    args.append('configure')
    assert main(args) == 1


def test_configure_failatmissingparams(base_args, tmpdir):
    """
    Configure has to fails if some arguments are missing
    in th econfiguration file provided at -c:
     - terraform
     - terraform::provider
    """

    # test has to fail as config is empty
    os.makedirs(os.path.join(tmpdir,'terraform','azure'))
    args = base_args(base_dir=tmpdir)
    args.append('configure')
    assert main(args) == 1

    # test has to fail as config has 'terraform' but no anything else
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w') as file:
        file.write(f"""terraform:""")
    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    assert main(args) == 1


def test_configure_checkterraformcloudprovider(base_args, tmpdir):
    """
    Configure has to fails if the folder structure
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
    Test configure has fail if
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