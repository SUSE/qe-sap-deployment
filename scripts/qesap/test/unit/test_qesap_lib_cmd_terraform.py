from unittest import mock
import json
import os
import logging
import pytest
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
    assert tfvar_content == "\nsandwiches = 5"


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

    ret = cmd_terraform(data, tmpdir, False)

    assert ret == 0
    # init stays plain: 'terraform init -json' needs Terraform 1.9+.
    # plan stays plain: 'terraform plan -json' has no resource attributes.
    # subprocess_run logs their output lines.
    # apply runs with '-json'. subprocess_run does not log the raw
    # JSON lines: cmd_terraform logs the derived text.
    subprocess_run.assert_has_calls(
        [
            mock.call(
                f"terraform -chdir={provider_folder} init -no-color",
                log_output=True,
            ),
            mock.call(
                f"terraform -chdir={provider_folder} plan -out=plan.zip -no-color",
                log_output=True,
            ),
            mock.call(
                f"terraform -chdir={provider_folder} apply -json -auto-approve plan.zip -no-color",
                log_output=False,
            ),
        ]
    )


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_workspace_logs_no_collision(subprocess_run, tmpdir):
    """
    The two 'workspace' commands of a destroy must write different log files.
    The old third-word rule gave both of them 'terraform.workspace.log.txt'.
    """
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
    subprocess_run.return_value = (0, ["line"])

    # Log files are written to the current folder. Remove the name that the
    # old third-word rule produced, so this test does not depend on leftovers
    # from previous runs.
    for leftover in [
        "terraform.workspace.log.txt",
        "terraform.workspace_select.log.txt",
        "terraform.workspace_delete.log.txt",
    ]:
        if os.path.isfile(leftover):
            os.remove(leftover)

    try:
        ret = cmd_terraform(data, tmpdir, False, workspace="ws1", destroy=True)

        assert ret == 0
        assert os.path.isfile("terraform.workspace_select.log.txt")
        assert os.path.isfile("terraform.workspace_delete.log.txt")
        # The colliding name from the old rule must not be created.
        assert not os.path.isfile("terraform.workspace.log.txt")
        # destroy and workspace steps are plain: no '-json', no .log.json file
        for call_args in subprocess_run.call_args_list:
            assert " -json" not in call_args[0][0]
        assert not os.path.isfile("terraform.destroy.log.json")
        assert not os.path.isfile("terraform.workspace_new.log.json")
    finally:
        for leftover in [
            "terraform.workspace_select.log.txt",
            "terraform.workspace_delete.log.txt",
            "terraform.destroy.log.txt",
        ]:
            if os.path.isfile(leftover):
                os.remove(leftover)


def _tf_conf_yaml():
    return """---
apiver: 3
provider: "lolo"
terraform:
  variables:
    sandwiches:
      - club
      - cheese
"""


def _make_provider_folder(tmpdir):
    provider_folder = tmpdir / "terraform" / "lolo"
    os.makedirs(provider_folder)
    return str(provider_folder)


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_json_steps_write_json_and_derived_txt(subprocess_run, tmpdir):
    """
    apply runs with '-json'. The raw JSON lines go to
    terraform.apply.log.json and the plain .log.txt contains the derived
    '@message' text, not the raw JSON. init and plan stay plain: they write
    their raw output to .log.txt and have no .log.json file.
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    _make_provider_folder(tmpdir)
    json_line = (
        '{"type":"log","level":"info","@message":"Apply complete! Resources: 1 added."}'
    )
    subprocess_run.return_value = (0, [json_line])

    cwd = os.getcwd()
    os.chdir(tmpdir)
    try:
        ret = cmd_terraform(data, tmpdir, False)
        assert ret == 0

        # init and plan are plain: raw output to .log.txt, no .log.json
        for step in ["init", "plan"]:
            with open(f"terraform.{step}.log.txt", encoding="utf-8") as f:
                assert f.read().splitlines() == [json_line]
            assert not os.path.isfile(f"terraform.{step}.log.json")

        with open("terraform.apply.log.json", encoding="utf-8") as f:
            assert f.read().splitlines() == [json_line]
        with open("terraform.apply.log.txt", encoding="utf-8") as f:
            assert f.read().splitlines() == ["Apply complete! Resources: 1 added."]
    finally:
        os.chdir(cwd)
        for leftover in [
            "terraform.init.log.txt",
            "terraform.init.log.json",
            "terraform.plan.log.txt",
            "terraform.plan.log.json",
            "terraform.apply.log.txt",
            "terraform.apply.log.json",
        ]:
            if os.path.isfile(leftover):
                os.remove(leftover)


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_diagnostic_detail_in_plain_log(subprocess_run, tmpdir):
    """
    A 'diagnostic' event contributes both its '@message' and its
    'diagnostic.detail' to the plain .log.txt, so that the error strings
    openQA searches for are present.
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    _make_provider_folder(tmpdir)
    diagnostic_line = json.dumps(
        {
            "@level": "error",
            "type": "diagnostic",
            "diagnostic": {
                "severity": "error",
                "summary": "Error creating resource",
                "detail": "An internal execution error occurred. Please retry later",
            },
            "@message": "Error: Error creating resource",
        }
    )
    subprocess_run.return_value = (0, [diagnostic_line])

    cwd = os.getcwd()
    os.chdir(tmpdir)
    try:
        ret = cmd_terraform(data, tmpdir, False)
        assert ret == 0
        # apply runs with '-json', so its .log.txt is derived from the events
        with open("terraform.apply.log.txt", encoding="utf-8") as f:
            lines = f.read().splitlines()
        assert "Error: Error creating resource" in lines
        assert "An internal execution error occurred. Please retry later" in lines
    finally:
        os.chdir(cwd)
        for leftover in [
            "terraform.init.log.txt",
            "terraform.init.log.json",
            "terraform.plan.log.txt",
            "terraform.plan.log.json",
            "terraform.apply.log.txt",
            "terraform.apply.log.json",
        ]:
            if os.path.isfile(leftover):
                os.remove(leftover)


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_non_json_lines_pass_through(subprocess_run, tmpdir):
    """
    A '-json' step whose output is not JSON passes the lines through
    unchanged to the plain .log.txt.
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    _make_provider_folder(tmpdir)
    subprocess_run.return_value = (0, ["plain warning line"])

    cwd = os.getcwd()
    os.chdir(tmpdir)
    try:
        ret = cmd_terraform(data, tmpdir, False)
        assert ret == 0
        # apply runs with '-json'; a non-JSON line is passed through unchanged
        with open("terraform.apply.log.txt", encoding="utf-8") as f:
            assert f.read().splitlines() == ["plain warning line"]
    finally:
        os.chdir(cwd)
        for leftover in [
            "terraform.init.log.txt",
            "terraform.init.log.json",
            "terraform.plan.log.txt",
            "terraform.plan.log.json",
            "terraform.apply.log.txt",
            "terraform.apply.log.json",
        ]:
            if os.path.isfile(leftover):
                os.remove(leftover)


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_failed_json_step_writes_both_files(subprocess_run, tmpdir):
    """
    A non-zero return from a '-json' step returns an error Status and still
    writes both the .log.json and the derived .log.txt files.
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    _make_provider_folder(tmpdir)
    json_line = '{"type":"log","level":"info","@message":"boom"}'
    # init (plain, ok), plan (plain, ok), apply (-json, fails)
    subprocess_run.side_effect = [(0, ["init"]), (0, ["plan"]), (1, [json_line])]

    cwd = os.getcwd()
    os.chdir(tmpdir)
    try:
        ret = cmd_terraform(data, tmpdir, False)
        assert ret != 0
        # apply failed: both files exist
        assert os.path.isfile("terraform.apply.log.json")
        with open("terraform.apply.log.txt", encoding="utf-8") as f:
            assert f.read().splitlines() == ["boom"]
    finally:
        os.chdir(cwd)
        for leftover in [
            "terraform.init.log.txt",
            "terraform.init.log.json",
            "terraform.plan.log.txt",
            "terraform.plan.log.json",
            "terraform.apply.log.txt",
            "terraform.apply.log.json",
        ]:
            if os.path.isfile(leftover):
                os.remove(leftover)


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_dryrun_prints_json_flag(subprocess_run, tmpdir, capsys):
    """
    In dryrun mode apply is printed with '-json', init and plan without it,
    and nothing is written.
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    provider_folder = _make_provider_folder(tmpdir)

    ret = cmd_terraform(data, tmpdir, True)
    assert ret == 0
    subprocess_run.assert_not_called()
    out = capsys.readouterr().out
    assert provider_folder in out
    # init stays plain
    assert f"{provider_folder} init -no-color" in out
    # plan stays plain, apply runs with '-json'
    assert "plan -out=plan.zip -no-color" in out
    assert "plan -json" not in out
    assert "apply -json -auto-approve plan.zip -no-color" in out
    assert not os.path.isfile("terraform.init.log.txt")


@pytest.mark.parametrize(
    "returncode, level",
    [(0, logging.DEBUG), (1, logging.ERROR)],
)
@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_log_has_derived_text(
    subprocess_run, tmpdir, caplog, returncode, level
):
    """
    The derived plain text of a '-json' step is logged as 'OUTPUT: <line>',
    in the same format and at the same level as subprocess_run logs a plain
    step: DEBUG on success (visible only with '--verbose'), ERROR on failure.
    The raw JSON line is not logged.
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    _make_provider_folder(tmpdir)
    json_line = (
        '{"type":"log","level":"info","@message":"Apply complete! Resources: 1 added."}'
    )
    # init (plain, ok), plan (plain, ok), apply (-json, returncode under test)
    subprocess_run.side_effect = [
        (0, ["init done"]),
        (0, ["plan done"]),
        (returncode, [json_line]),
    ]

    cwd = os.getcwd()
    os.chdir(tmpdir)
    try:
        with caplog.at_level(logging.DEBUG, logger="QESAP"):
            ret = cmd_terraform(data, tmpdir, False)
        assert (ret == 0) == (returncode == 0)
        derived = [
            rec
            for rec in caplog.records
            if rec.message == "OUTPUT: Apply complete! Resources: 1 added."
        ]
        assert len(derived) == 1
        assert derived[0].levelno == level
        # the raw JSON line never reaches the log
        assert not any(json_line in rec.message for rec in caplog.records)
    finally:
        os.chdir(cwd)
        for leftover in [
            "terraform.init.log.txt",
            "terraform.init.log.json",
            "terraform.plan.log.txt",
            "terraform.plan.log.json",
            "terraform.apply.log.txt",
            "terraform.apply.log.json",
        ]:
            if os.path.isfile(leftover):
                os.remove(leftover)


def _apply_plain_log(subprocess_run, tmpdir, monkeypatch, apply_lines):
    """Run cmd_terraform with apply_lines as the output of 'apply -json'.

    Returns:
        list of str: the lines of the derived terraform.apply.log.txt
    """
    data = yaml.load(_tf_conf_yaml(), Loader=yaml.FullLoader)
    _make_provider_folder(tmpdir)
    # init (plain), plan (plain), apply (-json)
    subprocess_run.side_effect = [(0, ["init"]), (0, ["plan"]), (0, apply_lines)]
    monkeypatch.chdir(tmpdir)
    assert cmd_terraform(data, tmpdir, False) == 0
    with open("terraform.apply.log.txt", encoding="utf-8") as f:
        return f.read().splitlines()


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_apply_log_has_output_values(subprocess_run, tmpdir, monkeypatch):
    """
    The plain apply log has the name and value of each output, in the same
    format as the plain 'terraform apply': sorted by name, 'tolist()' and
    'tomap()' for list and map values, no wrapper for tuples and objects,
    and '<sensitive>' instead of the value of a sensitive output.
    """
    outputs_event = {
        "@message": "Outputs: 7",
        "type": "outputs",
        "outputs": {
            "ip": {
                "sensitive": False,
                "type": ["list", "string"],
                "value": ["10.0.0.1", "10.0.0.2"],
            },
            "empty": {"sensitive": False, "type": ["tuple", []], "value": []},
            "Timestamp": {
                "sensitive": False,
                "type": "string",
                "value": "2026-11-19T20:14:09Z",
            },
            "tags": {
                "sensitive": False,
                "type": ["map", "string"],
                "value": {"a": "1", "long_key": "2"},
            },
            "obj": {
                "sensitive": False,
                "type": ["object", {"name": "string", "size": "number"}],
                "value": {"name": "vm", "size": 3},
            },
            "flag": {"sensitive": False, "type": "bool", "value": True},
            "password": {"sensitive": True, "type": "string", "value": "secret"},
        },
    }
    lines = _apply_plain_log(
        subprocess_run,
        tmpdir,
        monkeypatch,
        [
            '{"type":"change_summary","@message":"Apply complete! Resources: 1 added."}',
            json.dumps(outputs_event),
        ],
    )
    assert lines == [
        "Apply complete! Resources: 1 added.",
        "Outputs:",
        "",
        'Timestamp = "2026-11-19T20:14:09Z"',
        "empty = []",
        "flag = true",
        "ip = tolist([",
        '  "10.0.0.1",',
        '  "10.0.0.2",',
        "])",
        "obj = {",
        '  name = "vm"',
        "  size = 3",
        "}",
        "password = <sensitive>",
        "tags = tomap({",
        '  "a"        = "1"',
        '  "long_key" = "2"',
        "})",
    ]
    assert not any("secret" in line for line in lines)


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_apply_log_no_outputs(subprocess_run, tmpdir, monkeypatch):
    """
    Without outputs, the plain apply log has no 'Outputs:' line,
    like the plain 'terraform apply'.
    """
    lines = _apply_plain_log(
        subprocess_run,
        tmpdir,
        monkeypatch,
        ['{"type":"outputs","@message":"Outputs: 0","outputs":{}}'],
    )
    assert lines == []


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_apply_log_skips_plan_events(subprocess_run, tmpdir, monkeypatch):
    """
    The plain 'terraform apply plan.zip' does not print the version and does
    not print the plan again: the 'version' and 'planned_change' events are
    not in the plain apply log.
    """
    lines = _apply_plain_log(
        subprocess_run,
        tmpdir,
        monkeypatch,
        [
            '{"type":"version","@message":"Terraform 1.5.7"}',
            '{"type":"planned_change","@message":"local_file.foo: Plan to create"}',
            '{"type":"apply_start","@message":"local_file.foo: Creating..."}',
        ],
    )
    assert lines == ["local_file.foo: Creating..."]


@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_apply_log_diagnostic_location(
    subprocess_run, tmpdir, monkeypatch
):
    """
    A 'diagnostic' event has the resource address, the source location,
    the source line and the detail in the plain apply log.
    """
    diagnostic = {
        "type": "diagnostic",
        "@message": "Error: creating Linux Virtual Machine",
        "diagnostic": {
            "severity": "error",
            "summary": "creating Linux Virtual Machine",
            "detail": "ConflictingConcurrentWriteNotAllowed",
            "address": "module.hana_node.azurerm_linux_virtual_machine.hana[0]",
            "range": {
                "filename": "modules/hana_node/main.tf",
                "start": {"line": 42, "column": 1},
            },
            "snippet": {
                "context": 'resource "azurerm_linux_virtual_machine" "hana"',
                "code": 'resource "azurerm_linux_virtual_machine" "hana" {',
                "start_line": 42,
            },
        },
    }
    lines = _apply_plain_log(
        subprocess_run, tmpdir, monkeypatch, [json.dumps(diagnostic)]
    )
    assert lines == [
        "Error: creating Linux Virtual Machine",
        "  with module.hana_node.azurerm_linux_virtual_machine.hana[0],",
        '  on modules/hana_node/main.tf line 42, in resource "azurerm_linux_virtual_machine" "hana":',
        '  42: resource "azurerm_linux_virtual_machine" "hana" {',
        "ConflictingConcurrentWriteNotAllowed",
    ]


@pytest.mark.parametrize(
    "event",
    [
        {"type": "diagnostic", "@message": "Warning: w", "diagnostic": None},
        {"type": "diagnostic", "@message": "Warning: w", "diagnostic": "text"},
        {"type": "outputs", "@message": "Outputs: 1", "outputs": None},
        {"type": "outputs", "@message": "Outputs: 1", "outputs": {"x": None}},
        {"type": "apply_start", "@message": 42},
    ],
)
@mock.patch("lib.process_manager.subprocess_run")
def test_cmd_terraform_apply_log_unexpected_event_format(
    subprocess_run, tmpdir, monkeypatch, event
):
    """
    An event with an unexpected format does not stop qesap.py:
    the step is OK and the apply log is written.
    """
    _apply_plain_log(subprocess_run, tmpdir, monkeypatch, [json.dumps(event)])
