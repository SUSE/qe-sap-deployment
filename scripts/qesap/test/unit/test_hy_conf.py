import os
import pytest
from hypothesis import given, example, strategies as st
from lib.config import CONF
import logging

log = logging.getLogger(__name__)

# Strategy for values that can appear in terraform.variables,
# matching types handled by lib.config.yaml_to_tfvars_entry
tf_var_value_strategy = st.one_of(
    st.text(max_size=50),
    st.integers(min_value=-10000, max_value=10000),
    st.booleans(),
    st.lists(st.text(max_size=20), min_size=0, max_size=5),
    st.dictionaries(
        keys=st.text(min_size=1, max_size=20),
        values=st.text(max_size=20),  # yaml_to_tfvars_entry for dicts expects string values
        min_size=0, max_size=3
    )
)

# Strategy for the 'terraform.variables' dictionary
tf_variables_strategy = st.dictionaries(
    keys=st.text(min_size=1, max_size=30),  # Terraform variable names
    values=tf_var_value_strategy,
    min_size=0,
    max_size=5  # Limit number of terraform variables
)

# Strategy for the 'terraform' section content.
# It can be None, or a dict that might contain 'variables', 'bin'
# We intentionally skip 'tfvars_template' as it is not a feature we like to test.
terraform_section_content_strategy = st.one_of(
    st.none(),  # Allows for terraform: null
    st.fixed_dictionaries(
        {},  # No mandatory keys if all are optional
        optional={
            'variables': tf_variables_strategy,
            'bin': st.text(max_size=50),
            # 'tfvars_template': st.text(max_size=100) # Path-like string
        }
    )
)

# Strategy for general values for other arbitrary keys in the conf.yaml,
# other than the one in terraform and intentionally avoiding ansible key
# These can be simple types or somewhat nested lists/dictionaries.
# Keys within nested dictionaries are also filtered to not be 'ansible'.
general_not_ansible_value_strategy = st.recursive(
    base=st.one_of(st.none(), st.booleans(), st.integers(), st.text(max_size=20)),
    extend=lambda children: st.one_of(
        st.lists(children, min_size=0, max_size=3),
        st.dictionaries(
            keys=st.text(min_size=1, max_size=10).filter(lambda k: k != 'ansible'),
            values=children,
            min_size=0, max_size=3
        )
    ),
    max_leaves=8  # Limit complexity of generated structures
)


@st.composite
def config_maps_without_ansible(draw):
    """
    Generates configuration-like dictionaries that do not have 'ansible' as a top-level key.
    The structure attempts to be more representative of actual qe-sap-deployment config files.
    """
    config = {}
    structured_parts = {
        'apiver': st.integers(min_value=0, max_value=5),  # 5 as we are at apiver:3 and about to add 4
        'provider': st.text(min_size=1, max_size=20),
        'terraform': terraform_section_content_strategy,
    }
    for key_name, strategy_instance in structured_parts.items():
        if draw(st.booleans()):
            config[key_name] = draw(strategy_instance)
    num_extra_items = draw(st.integers(min_value=0, max_value=3))
    for _ in range(num_extra_items):
        extra_key = draw(st.text(min_size=1, max_size=15).filter(lambda k: k != 'ansible' and k not in config))
        if extra_key in config or extra_key == 'ansible':
            continue
        config[extra_key] = draw(general_not_ansible_value_strategy)
    return config


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@example({})
@example({'apiver': '3', 'terraform': ''})
@given(st.dictionaries(st.text(), st.text()).filter(lambda x: 'ansible' not in x))
def test_conf_has_not_ansible(conf_dict):
    conf = CONF(conf_dict)
    assert conf.has_ansible() is False


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@given(config_maps_without_ansible())
def test_conf_has_not_ansible_with_better_strategy(conf_dict):
    conf = CONF(conf_dict)
    log.error("conf:%s conf_dict:%s", conf, conf_dict)
    assert conf.has_ansible() is False


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@given(st.dictionaries(st.text(), st.text()), st.dictionaries(st.text(), st.text()))
def test_conf_has_ansible(conf_dict, conf_ansible):
    data = conf_dict
    data['ansible'] = conf_ansible
    conf = CONF(data)
    assert conf.has_ansible() is True


@pytest.mark.skipif("FUZZYTEST" not in os.environ, reason="Fuzzy test disabled by default")
@given(st.dictionaries(st.text(), st.text()))
def test_yaml_to_tfvars(conf_dict_date):
    conf_dict = dict()
    conf_dict['terraform'] = dict()
    conf_dict['terraform']['variables'] = conf_dict_date
    conf = CONF(conf_dict)
    if conf.terraform_yml():
        tfvars = conf.yaml_to_tfvars()
        assert isinstance(tfvars, str)
