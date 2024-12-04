from unittest import mock
import os
import logging
import yaml

from lib.config import CONF
from lib.cmds import create_tfvars, cmd_terraform

log = logging.getLogger(__name__)


def test_create_tfvars_string():
    """
    Try .tfvars generation for string terraform variables format in config.yaml
    """

    # This test overlap a little bit with test_tfvars_yaml
    conf_yaml = """---
terraform:
  variables:
    az_region: "westeurope"
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_content, err = create_tfvars(config, None)

    assert err is None, "Unexpected err from create_tfvars:" + str(err)
    assert tfvar_content == '\naz_region = "westeurope"'


def test_create_tfvars_int():
    """
    Try .tfvars generation for int terraform variables format in config.yaml
    """
    conf_yaml = """---
terraform:
  variables:
    sandwiches: 5
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_content, err = create_tfvars(config, None)

    assert err is None, "Unexpected err from create_tfvars:" + str(err)
    assert tfvar_content == '\nsandwiches = 5'


def test_create_tfvars_list():
    """
    Try .tfvars generation for list terraform variables format in config.yaml
    """
    conf_yaml = """---
terraform:
  variables:
    sandwiches:
      - tuna
      - club
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_content, err = create_tfvars(config, None)

    assert err is None, "Unexpected err from create_tfvars:" + str(err)
    assert tfvar_content == '\nsandwiches = ["tuna", "club"]'


def test_create_tfvars_unsupported_format():
    """
    Try .tfvars generation for float in conf.yaml result in an error
    """
    conf_yaml = """---
terraform:
  variables:
    sandwiches: 3.14
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_content, err = create_tfvars(config, None)

    assert err is not None, "Unexpected None err"


def test_create_tfvars_string_with_template(tmpdir):
    """
    Try .tfvars generation from .tfvar.template and conf.yaml without overlapping variables
    """
    conf_yaml = """---
terraform:
  variables:
    sandwiches: "club"
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_template_file = str(tmpdir / "gnocchi.txt")
    with open(tfvar_template_file, "w", encoding="utf-8") as file:
        file.write("# This is a comment")

    tfvar_content, err = create_tfvars(config, tfvar_template_file)

    log.error(tfvar_content)
    assert err is None, "Unexpected err from create_tfvars:" + str(err)
    assert "# This is a comment\n" in tfvar_content
    assert 'sandwiches = "club"\n' in tfvar_content


def test_create_tfvars_string_with_template_and_substitution(tmpdir):
    """
    Try .tfvars generation from .tfvar.template and conf.yaml with overlapping string variables
    """
    conf_yaml = """---
terraform:
  variables:
    sandwiches: "club"
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_template_file = str(tmpdir / "gnocchi.txt")
    with open(tfvar_template_file, "w", encoding="utf-8") as file:
        file.write('sandwiches = "cheese"')

    tfvar_content, err = create_tfvars(config, tfvar_template_file)

    log.error(tfvar_content)
    assert err is None, "Unexpected err from create_tfvars:" + str(err)
    assert 'sandwiches = "club"\n' in tfvar_content


def test_create_tfvars_list_with_template_and_substitution(tmpdir):
    """
    Try .tfvars generation from .tfvar.template and conf.yaml with overlapping list variables
    """
    conf_yaml = """---
terraform:
  variables:
    sandwiches:
      - club
      - cheese
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    config = CONF(data)
    tfvar_template_file = str(tmpdir / "gnocchi.txt")
    with open(tfvar_template_file, "w", encoding="utf-8") as file:
        file.write('sandwiches = ["tuna", "vegan"]')

    tfvar_content, err = create_tfvars(config, tfvar_template_file)

    log.error(tfvar_content)
    assert err is None, "Unexpected err from create_tfvars:" + str(err)
    assert 'sandwiches = ["club", "cheese"]\n' in tfvar_content


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform(subprocess_run, tmpdir):
    """
    This test coverage overlap with tests from
    scripts/qesap/test/unit/test_qesap_terraform.py

    this one is calling lower API than the other
    """

    # Set env and input
    conf_yaml = """---
apiver: 3
provider: "lolo"
terraform:
  variables:
    sandwiches:
      - club
      - cheese
"""
    data = yaml.load(conf_yaml, Loader=yaml.FullLoader)
    provider_folder = tmpdir / "terraform" / "lolo"
    os.makedirs(provider_folder)
    subprocess_run.return_value = (
        0,
        ["This is the terraform output", "Two lines of that"],
    )

    # Set expectation
    calls = []
    terraform_cmd = ["terraform", f"-chdir={provider_folder}"]
    # Just test one of them
    terraform_cmd.append("init")
    terraform_cmd.append("-no-color")
    calls.append(mock.call(terraform_cmd))

    ret = cmd_terraform(data, tmpdir, False)

    assert ret == 0

    subprocess_run.assert_has_calls(calls)
