import re
from lib.config import CONF


def test_tfvars_yaml_string():
    """
    Check string variable format tfvars output
    :param config_data_sample:
    input similar to yaml config file
    :return:
    true or false
    """
    expected_result = r"gianni = \"pinotto\""
    c = CONF({"terraform": {"variables": {"gianni": "pinotto"}}})
    actual_result = c.yaml_to_tfvars()
    assert re.search(expected_result, actual_result)


def test_tfvars_yaml_int():
    """
    Check int variable format tfvars output
    :param config_data_sample:
    input similar to yaml config file
    :return:
    true or false
    """
    expected_result = r"gianni = 42"
    c = CONF({"terraform": {"variables": {"gianni": 42}}})
    actual_result = c.yaml_to_tfvars()
    assert re.search(expected_result, actual_result)


def test_tfvars_yaml_bool():
    """
    Check bool variable format tfvars output
    :param config_data_sample:
    input similar to yaml config file
    :return:
    true or false
    """
    expected_result = r"gianni = true"
    c = CONF({"terraform": {"variables": {"gianni": (1 == 1)}}})
    actual_result = c.yaml_to_tfvars()
    assert re.search(expected_result, actual_result)

    expected_result = r"gianni = false"
    c = CONF({"terraform": {"variables": {"gianni": not True}}})
    actual_result = c.yaml_to_tfvars()
    assert re.search(expected_result, actual_result)


def test_tfvars_yaml_list(config_data_sample):
    """
    Check list based variable format tfvars output
    :param config_data_sample:
    input similar to yaml config file
    :return:
    true or false
    """
    hana_ips = ["10.0.0.2", "10.0.0.3"]
    expected_result = r'hana_ips = \["10.0.0.2", "10.0.0.3"]'
    c = CONF(config_data_sample(hana_ips))
    actual_result = c.yaml_to_tfvars()
    assert re.search(expected_result, actual_result)


def test_tfvars_yaml_dict(config_data_sample):
    """
    Check dict based variable format tfvars output
    :param config_data_sample:
    :return:
    """
    hana_disk_configuration = {"disk_type": "hdd,hdd,hdd", "disks_size": "64,64,64"}

    expected_result = (
        r"hana_data_disks_configuration = {"
        r'(\s|\t)+disk_type = "hdd,hdd,hdd"'
        r'(\s|\t)+disks_size = "64,64,64"'
    )
    c = CONF(config_data_sample(hana_disk_configuration))
    actual_result = c.yaml_to_tfvars()
    assert re.search(expected_result, actual_result)
