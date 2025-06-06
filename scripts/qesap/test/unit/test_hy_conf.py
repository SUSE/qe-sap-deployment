import os
import pytest
from hypothesis import given, example
from hypothesis.strategies import dictionaries, text
from lib.config import CONF


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@example({})
@example({'apiver': '3', 'terraform': ''})
@given(dictionaries(text(), text()).filter(lambda x: 'ansible' not in x))
def test_conf_has_not_ansible(conf_dict):
    conf = CONF(conf_dict)
    assert conf.has_ansible() is False


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@given(dictionaries(text(), text()), dictionaries(text(), text()))
def test_conf_has_ansible(conf_dict, conf_ansible):
    data = conf_dict
    data['ansible'] = conf_ansible
    conf = CONF(data)
    assert conf.has_ansible() is True


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@given(dictionaries(text(), text()))
def test_yaml_to_tfvars(conf_dict_date):
    conf_dict = dict()
    conf_dict['terraform'] = dict()
    conf_dict['terraform']['variables'] = conf_dict_date
    conf = CONF(conf_dict)
    if conf.terraform_yml():
        tfvars = conf.yaml_to_tfvars()
        assert isinstance(tfvars, str)
