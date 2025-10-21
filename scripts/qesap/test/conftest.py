import os
import yaml
from unittest import mock
import pytest


# pylint: disable=redefined-outer-name


@pytest.fixture()
def config_data_sample():
    """
    Config data as if obtained from yaml file.
    'variables' section must contains only one string, list and dict.
    :return:
    dict based data structure
    """

    def _callback(
        provider="pinocchio",
        az_region="westeurope",
        hana_ips=None,
        hana_disk_configuration=None,
    ):

        # Default values
        hana_ips = hana_ips if hana_ips else ["10.0.0.2", "10.0.0.3"]
        hana_disk_configuration = (
            hana_disk_configuration
            if hana_disk_configuration
            else {"disk_type": "hdd,hdd,hdd", "disks_size": "64,64,64"}
        )

        # Config template
        config = {
            "name": "geppetto",
            "terraform": {
                "provider": provider,
                "variables": {
                    "az_region": az_region,
                    "hana_ips": hana_ips,
                    "hana_data_disks_configuration": hana_disk_configuration,
                },
            },
            "ansible": {
                "hana_urls": ["SAPCAR_URL", "SAP_HANA_URL", "SAP_CLIENT_SAR_URL"]
            },
        }

        return config

    return _callback


@pytest.fixture
def config_yaml_sample():
    """
    create yaml config data sample with one string, list and dict variable.
    :return:
    dict based data structure
    """
    config = """---
apiver: {}
provider: {}
terraform:
  {}
  variables:
    az_region: "westeurope"
    hana_ips: ["10.0.0.2", "10.0.0.3"]
    hana_data_disks_configuration:
      disk_type: "hdd,hdd,hdd"
      disks_size: "64,64,64"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  az_sas_token: SECRET
  hana_media:
    - SAPCAR_EXE
    - SAP_HANA_EXE
    - SAP_CLIENT_SAR_EXE
  hana_vars:
    sap_hana_install_software_directory: /hana/shared/install
    sap_hana_install_master_password: 'DoNotUseThisPassw0rd'
    sap_hana_install_sid: 'UT0'
    sap_hana_install_instance_number: '00'
    sap_domain: "qe-test.example.com"
    primary_site: 'goofy'
    secondary_site: 'miky'
"""

    def _callback(provider="pinocchio", apiver=3, template_file=None):
        tfvar_template_setting = ""
        if template_file is not None:
            tfvar_template_setting = f"tfvar_template: {template_file}"

        return config.format(apiver, provider, tfvar_template_setting)

    return _callback


@pytest.fixture
def config_yaml_sample_for_terraform():
    """
    create yaml config data sample with one string, list and dict variable.
    :return:
    dict based data structure
    """
    config = """---
apiver: {}
provider: {}
{}
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  az_sas_token: SECRET
  hana_media:
    - SAPCAR_EXE
    - SAP_HANA_EXE
    - SAP_CLIENT_SAR_EXE
  hana_vars:
    sap_hana_install_software_directory: /hana/shared/install
    sap_hana_install_master_password: 'DoNotUseThisPassw0rd'
    sap_hana_install_sid: 'UT0'
    sap_hana_install_instance_number: '00'
    sap_domain: "qe-test.example.com"
    primary_site: 'goofy'
    secondary_site: 'miky'
"""

    def _callback(terraform_section, provider="pinocchio", apiver=3):
        return config.format(apiver, provider, terraform_section)

    return _callback


@pytest.fixture
def provider_dir(tmpdir):
    '''
       It also implicitly create the terraform folder if missing
    '''
    def _callback(provider):
        provider_path = os.path.join(tmpdir, "terraform", provider)
        if not os.path.isdir(provider_path):
            os.makedirs(provider_path)
        return provider_path

    return _callback


@pytest.fixture
def playbooks_dir(tmpdir):
    def _callback():
        playbooks_path = os.path.join(tmpdir, "ansible", "playbooks")
        if not os.path.isdir(playbooks_path):
            os.makedirs(playbooks_path)
        return playbooks_path

    return _callback


@pytest.fixture
def create_playbooks(playbooks_dir):
    def _callback(playbook_list):
        playbook_filename_list = []
        for playbook in playbook_list:
            ans_plybk_path = playbooks_dir()
            playbook_filename = os.path.join(ans_plybk_path, playbook + ".yaml")
            with open(playbook_filename, "w", encoding="utf-8") as file:
                file.write("")
            playbook_filename_list.append(playbook_filename)
        return playbook_filename_list

    return _callback


@pytest.fixture
def ansible_config():
    def _callback(provider, playbooks, apiver=3):
        config_content = f"""---
apiver: {apiver}
provider: {provider}
ansible:
    az_container_name: pippo
    az_storage_account_name: pippo
    az_sas_token: SECRET
    hana_media:
    - pippo"""

        if apiver < 4:
            for seq in playbooks:
                config_content += f"\n    {seq}:"
                for play in playbooks[seq]:
                    config_content += f"\n        - {play}.yaml"
        else:
            config_content += "\n    sequences:"
            for seq in playbooks:
                config_content += f"\n        {seq}:"
                for play in playbooks[seq]:
                    config_content += f"\n            - {play}.yaml"
        return config_content

    return _callback


FAKE_BIN_PATH = "/paese/della/cuccagna/"
ANSIBLE_EXE = FAKE_BIN_PATH + "ansible"
ANSIBLEPB_EXE = FAKE_BIN_PATH + "ansible-playbook"


@pytest.fixture()
def ansible_exe_call():
    def _callback(inventory):
        return f"{ANSIBLE_EXE} -vv -i {inventory} all -a true --ssh-extra-args=\"-l cloudadmin -o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new\""

    return _callback


@pytest.fixture
def mock_call_ansibleplaybook():
    """
    create a mock.call with some default elements
    ```
    mock.call('ansible-playbook -i inventory, playbook', env={'ANSIBLE_PIPELINING', 'True'})
    ```
    """

    def _callback(inventory, playbook, verbosity="-vv", arguments=None, env=None):
        playbook_cmd = [ANSIBLEPB_EXE, verbosity, "-i", inventory, playbook]
        if arguments is not None:
            playbook_cmd += arguments
        if env is None:
            original_env = dict(os.environ)
            original_env["ANSIBLE_PIPELINING"] = "True"
            original_env["ANSIBLE_TIMEOUT"] = "20"
        else:
            original_env = env
        return mock.call(cmd=' '.join(playbook_cmd), env=original_env)

    return _callback


@pytest.fixture
def create_inventory(provider_dir):
    """
    Create an empty inventory file
    """

    def _callback(provider):
        provider_path = provider_dir(provider)
        inventory_filename = os.path.join(provider_path, "inventory.yaml")
        with open(inventory_filename, "w", encoding="utf-8") as file:
            file.write("")
        return inventory_filename

    return _callback


@pytest.fixture
def base_args(tmpdir):
    """
    Return bare minimal list of arguments to run any sub-command
    Args:
        base_dir (str): used for -b
        config_file (str): used for -c
    """

    def _callback(base_dir=None, config_file=None, verbose=True):
        args = []
        if verbose:
            args.append("--verbose")

        args.append("--base-dir")
        if base_dir is None:
            args.append(str(tmpdir))
        else:
            args.append(str(base_dir))

        args.append("--config-file")
        if config_file is None:
            # create an empty config.yaml
            config_file_name = str(tmpdir / "config.yaml")
            with open(config_file_name, "w", encoding="utf-8") as file:
                file.write("")
            args.append(config_file_name)
        else:
            args.append(config_file)
        return args

    return _callback


@pytest.fixture
def args_helper(tmpdir, base_args, provider_dir):
    def _callback(provider, conf, tfvar_template=None):
        provider_path = provider_dir(provider)
        tfvar_path = os.path.join(provider_path, "terraform.tfvars")

        ansiblevars_path = os.path.join(tmpdir, "ansible", "playbooks", "vars")
        if not os.path.isdir(ansiblevars_path):
            os.makedirs(ansiblevars_path)
        hana_media = os.path.join(ansiblevars_path, "hana_media.yaml")
        hana_vars = os.path.join(ansiblevars_path, "hana_vars.yaml")

        config_file_name = str(tmpdir / "config.yaml")
        with open(config_file_name, "w", encoding="utf-8") as file:
            file.write(conf)
        if tfvar_template is not None:
            with open(tfvar_template["file"], "w", encoding="utf-8") as file:
                for line in tfvar_template["data"]:
                    file.write(line)

        args = base_args(base_dir=tmpdir, config_file=config_file_name)
        return args, provider_path, tfvar_path, hana_media, hana_vars

    return _callback


@pytest.fixture
def configure_helper(args_helper):
    '''
       Only suitable for tests about the configure sub-command
    '''
    def _callback(provider, conf, tfvar_template=None):
        args, _, tfvar_path, hana_media, hana_vars = args_helper(
            provider, conf, tfvar_template
        )
        args.append("configure")
        return args, tfvar_path, hana_media, hana_vars

    return _callback


@pytest.fixture
def create_config():
    """Create one element for the list in the configure.json related to trento_deploy.py -s"""

    def _callback(typ, reg, ver):
        config = {"type": typ, "registry": reg}
        if ver:
            config["version"] = ver
        return config

    return _callback


@pytest.fixture
def line_match():
    """
    return True if matcher string is present at least one in the string_list
    """

    def _callback(string_list, matcher):
        return len([s for s in string_list if matcher in s]) > 0

    return _callback


@pytest.fixture
def check_duplicate():
    """
    Fixture to test trento_cluster_install.sh content
    Check for duplicated lines

    Args:
        lines (list(str)): list of string, each string is a trento_cluster_install.sh line

        Returns:
            tuple: True/False result, if False str about the error message
    """

    def _callback(lines):
        for line in lines:
            if len([s for s in lines if line.strip() in s.strip()]) != 1:
                return (False, "Line '" + line + "' appear more than one time")
            if "--set" in line:
                setting = line.split(" ")[1]
                setting_field = setting.split("=")[0]
                if len([s for s in lines if setting_field in s]) != 1:
                    return (
                        False,
                        "Setting '" + setting_field + "' appear more than one time",
                    )
        return (True, "")

    return _callback


@pytest.fixture
def check_mandatory_args(capsys, tmpdir):
    """
    Given a cli to test and a subcommand string,
    check that both -c and -b are mandatory
    """

    def _callback(cli_to_test, subcmd):
        try:
            cli_to_test([subcmd])
        except SystemExit:
            pass
        captured = capsys.readouterr()
        if "error:" not in captured.err:
            return False

        # Try with b but without c
        try:
            cli_to_test(["-b", str(tmpdir), subcmd])
        except SystemExit:
            pass
        captured = capsys.readouterr()
        if "error:" not in captured.err:
            return False

        # Try with c but without b
        try:
            cli_to_test(["-c", str(tmpdir), subcmd])
        except SystemExit:
            pass
        captured = capsys.readouterr()
        if "error:" not in captured.err:
            return False
        return True

    return _callback


@pytest.fixture
def validate_hana_media():
    """
    Validate hana_media.yaml file needed by Ansible

    ```
    az_storage_account_name: <ACCOUNT>
    az_container_name:       <CONTAINER>
    az_sas_token:            <SAS_TOKEN>
    az_key_name:             <KEY>
    az_blobs:
      - <SAPCAR_EXE>
      - <IMDB_SERVER_SAR>
      - <IMDB_CLIENT_SAR>
    ```
    """

    def _callback(
        hana_media_file,
        account="ACCOUNT",
        container="CONTAINER",
        token=None,
        key=None,
        sapcar="SAPCAR_EXE",
        imdb_srv="IMDB_SERVER_SAR",
        imdb_cln="IMDB_CLIENT_SAR",
    ):
        with open(hana_media_file, "r", encoding="utf-8") as file:
            data = yaml.load(file, Loader=yaml.FullLoader)

            if "az_storage_account_name" not in data:
                return (
                    False,
                    "az_storage_account_name missing in the generated hana_media.yaml",
                )
            if account != data["az_storage_account_name"]:
                return (
                    False,
                    f"az_storage_account_name value is {data['az_storage_account_name']} and not expected {account}",
                )

            if "az_container_name" not in data:
                return (
                    False,
                    "az_container_name missing in the generated hana_media.yaml",
                )
            if container != data["az_container_name"]:
                return (
                    False,
                    f"az_container_name value is {data['az_container_name']} and not expected {container}",
                )

            # az_sas_token is optional, test it only if requested
            if token:
                if "az_sas_token" not in data:
                    return (
                        False,
                        "az_sas_token missing in the generated hana_media.yaml",
                    )
                if token != data["az_sas_token"]:
                    return (
                        False,
                        f"az_sas_token value is {data['az_sas_token']} and not expected {token}",
                    )

            # az_key_name is optional, test it only if requested
            if key:
                if "az_key_name" not in data:
                    return (
                        False,
                        "az_key_name missing in the generated hana_media.yaml",
                    )
                if key != data["az_key_name"]:
                    return (
                        False,
                        f"az_key_name value is {data['az_key_name']} and not expected {key}",
                    )

            blob_key = "az_blobs"
            if blob_key not in data:
                return (
                    False,
                    f"{blob_key} section missing in the generated hana_media.yaml",
                )
            urls_num = len(data[blob_key])
            if urls_num != 3:
                return (
                    False,
                    f"Number of elements in {blob_key} is {urls_num} and not 3",
                )
            if sapcar not in data[blob_key]:
                return False, f"{sapcar} missing in {blob_key}: {data[blob_key]}"
            if imdb_srv not in data[blob_key]:
                return False, f"{imdb_srv} missing in {blob_key}: {data[blob_key]}"
            if imdb_cln not in data[blob_key]:
                return False, f"{imdb_cln} missing in {blob_key}: {data[blob_key]}"

        return (True, "")

    return _callback
