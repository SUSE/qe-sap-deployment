import os
import yaml

from qesap import main


def test_configure_create_ansible_hanamedia(configure_helper, config_yaml_sample):
    """
    Test that 'configure' write a hana_media.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, _, hana_media, _ = configure_helper(provider, conf)

    assert main(args) == 0
    assert os.path.isfile(hana_media)


def test_configure_ansible_hanamedia_content_apiver3(configure_helper, validate_hana_media):
    """
    Test that an new apiver:3 config.yaml

    ```
    ansible:
      az_storage_account_name: <SOMETHING>
      az_container_name:  <CONTAINER>
      az_sas_token: <SAS_TOKEN>
      hana_media:
        - <SAPCAR_EXE>
        - <IMDB_SERVER_SAR>
        - <IMDB_CLIENT_SAR>
    ```

    during 'configure', write a hana_media.yaml with
    expected content

    ```
    az_storage_account_name: <SOMETHING>
    az_container_name:       <CONTAINER>
    az_sas_token:            <SAS_TOKEN>
    az_blobs:
      - <SAPCAR_EXE>
      - <IMDB_SERVER_SAR>
      - <IMDB_CLIENT_SAR>
    ```
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 3
provider: {provider}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  hana_media:
    - MY_SAPCAR_EXE
    - MY_IMDB_SERVER
    - MY_IMDB_CLIENT"""
    args, _, hana_media, _ = configure_helper(provider, conf)
    assert main(args) == 0

    res, msg = validate_hana_media(hana_media, account='SOMEONE', container='SOMETHING', token=None, sapcar='MY_SAPCAR_EXE', imdb_srv='MY_IMDB_SERVER', imdb_cln='MY_IMDB_CLIENT')
    assert res, msg


def test_configure_ansible_hanamedia_content_apiver3_with_apiver2_uri_format(configure_helper, validate_hana_media):
    """
    Test that the script reports an error if the user
    is using conf.yaml with new apiver:3
    but providing hana_media as full url like for apiver2
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 3
provider: {provider}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  hana_media:
    - https://SOMEONE.blob.core.windows.net/SOMETHING/MY_SAPCAR_EXE
    - https://SOMEONE.blob.core.windows.net/SOMETHING/MY_IMDB_SERVER
    - https://SOMEONE.blob.core.windows.net/SOMETHING/MY_IMDB_CLIENT"""
    args, _, hana_media, _ = configure_helper(provider, conf)
    assert main(args) == 1


def test_configure_ansible_hanamedia_content_apiver3_token(configure_helper, validate_hana_media):
    """
    Test that an new apiver:3 config.yaml optional param

    ```
    ansible:
      az_sas_token: <SAS_TOKEN>
    ```

    during 'configure', write a hana_media.yaml with

    ```
    az_sas_token:            <SAS_TOKEN>
    ```
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 3
provider: {provider}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  az_sas_token: SUPERSECRET
  hana_media:
    - MY_SAPCAR_EXE
    - MY_IMDB_SERVER
    - MY_IMDB_CLIENT"""
    args, _, hana_media, _ = configure_helper(provider, conf)
    assert main(args) == 0

    res, msg = validate_hana_media(hana_media, account='SOMEONE', container='SOMETHING', token='SUPERSECRET', sapcar='MY_SAPCAR_EXE', imdb_srv='MY_IMDB_SERVER', imdb_cln='MY_IMDB_CLIENT')
    assert res, msg


def test_configure_create_ansible_hanavars(configure_helper, config_yaml_sample):
    """
    Test that 'configure' write a hana_vars.yaml file in
    <BASE_DIR>/ansible/playbooks/vars
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, _, _, hana_vars = configure_helper(provider, conf)

    assert main(args) == 0
    assert os.path.isfile(hana_vars)


def test_configure_ansible_hanavar_content(configure_helper):
    """
    Test that 'configure' write a hana_vars.yaml with
    expected content
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 3
provider: {provider}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  hana_media:
    - MY_SAPCAR_EXE
  hana_vars:
    sap_hana_install_software_directory: /hana/shared/install
    sap_hana_install_master_password: 'DoNotUseThisPassw0rd'
    sap_hana_install_sid: 'HDB'
    sap_hana_install_instance_number: '00'
    sap_domain: "qe-test.example.com"
    primary_site: 'goofy'
    secondary_site: 'miky'
    zanzara: mosquito
    Moskito: komar
    moustique: komarac
"""
    args, _, _, hana_vars = configure_helper(provider, conf)
    assert main(args) == 0

    with open(hana_vars, 'r', encoding='utf-8') as file:
        data = yaml.load(file, Loader=yaml.FullLoader)
        assert 'zanzara' in data
        assert 'Moskito' in data
        assert 'moustique' in data
        assert data['zanzara'] == 'mosquito'
        assert data['Moskito'] == 'komar'
        assert data['moustique'] == 'komarac'
        assert len(data) == 10


def test_configure_ansible_hanavar_values(configure_helper):
    """
    Test about value of mandatory fields
    sap_hana_install_software_directory: string of path where to find HANA software
    sap_hana_install_master_password: password for <SID>adm user and databases
    sap_hana_install_sid: Three character SID of the DB.  See restrictions -> https://launchpad.support.sap.com/#/notes/1979280
    sap_hana_install_instance_number: two digit instance number
    sap_domain: FQDN with the actual hostname
    primary_site: name of the primary 'site' for HANA System Replication
    secondary_site: name of the secondary 'site' for HANA System Replication
    """
    provider = 'pinocchio'
    conf = """---
apiver: 3
provider: {}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  hana_media:
    - MY_SAPCAR_EXE
  hana_vars:
    sap_hana_install_software_directory: {}
    sap_hana_install_master_password: ''
    sap_hana_install_sid: '{}'
    sap_hana_install_instance_number: '{}'
    sap_domain: "qe-test.example.com"
    primary_site: 'goofy'
    secondary_site: 'miky'
"""
    args, _, _, hana_vars = configure_helper(provider, conf.format(provider, '/aaa/bbb/ccc', 'HDB', '00'))
    assert main(args) == 0
    args, _, _, hana_vars = configure_helper(provider, conf.format(provider, 'ccc', 'HDB', '00'))
    assert main(args) != 0, "Wrong 'sap_hana_install_software_directory'='ccc' not detected."
    args, _, _, hana_vars = configure_helper(provider, conf.format(provider, '/aaa/bbb/ccc', 'HD', '00'))
    assert main(args) != 0, "Wrong 'sap_hana_install_sid'='HD' not detected."
    args, _, _, hana_vars = configure_helper(provider, conf.format(provider, '/aaa/bbb/ccc', 'HDB', '0'))
    assert main(args) != 0, "Wrong 'sap_hana_install_instance_number'='0' not detected."
    args, _, _, hana_vars = configure_helper(provider, conf.format(provider, '/aaa/bbb/ccc', 'HDB', 'AA'))
    assert main(args) != 0, "Wrong 'sap_hana_install_instance_number'='AA' not detected."
    args, _, _, hana_vars = configure_helper(provider, conf.format(provider, '/aaa/bbb/ccc', 'HDB', '000'))
    assert main(args) != 0, "Wrong 'sap_hana_install_instance_number'='000' not detected."


def test_configure_ansible_hana(configure_helper):
    """
    Test that 'configure' fails if manadatory params are missing
    """
    provider = 'pinocchio'
    conf = f"""---
apiver: 3
provider: {provider}
terraform:
    variables:
        az_region: "westeurope"
ansible:
  az_storage_account_name: SOMEONE
  az_container_name: SOMETHING
  hana_media:
    - MY_SAPCAR_EXE
  hana_vars:
    zanzara: mosquito
"""
    args, _, _, hana_vars = configure_helper(provider, conf)
    assert main(args) != 0
