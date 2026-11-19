import logging

from lib.process_manager import log_output_lines, subprocess_run


def test_no_command():
    """
    Run subprocess_run providing no commands
    result in an error
    """
    exit_code, stdout_list = subprocess_run([])
    assert exit_code == 1
    assert stdout_list == []


def test_echo():
    """
    Run subprocess_run using the true subprocess.
    Test is really running an echo command
    and check the stdout.
    """
    test_text = "Banana"
    exit_code, stdout_list = subprocess_run(f'echo "{test_text}"')
    assert exit_code == 0
    assert stdout_list == [test_text]


def test_multilines():
    """
    each stdout line has to be in a different stdout array element
    """
    str_list = ["a", "b", "c"]
    test_text = ""
    for string in str_list:
        test_text += (string * 10) + "\n"
    _, stdout_list = subprocess_run(f'echo "{test_text}"')
    assert len(stdout_list) == len(str_list) + 1
    for i, line in enumerate(str_list):
        assert line * 10 == stdout_list[i].strip()


def test_stderr():
    """
    Run subprocess_run redirect the stderr to stdout
    """
    test_text = "Banana"
    exit_code, stdout_list = subprocess_run(f"logger -s {test_text}")
    assert exit_code == 0
    assert len(stdout_list) > 0


def test_err():
    """
    Run subprocess_run with a command that fails
    """
    not_existing_file = "Banana"

    exit_code, stdout_list = subprocess_run(f"cat {not_existing_file}")
    assert exit_code == 1
    assert len(stdout_list) > 0


def test_env():
    """
    Check that env variable are controllable
    """
    _, stdout_list = subprocess_run("printenv")
    assert "BANANA_VALUE" not in stdout_list
    exit_code, stdout_list = subprocess_run("printenv", env={"BANANA_VALUE": "1234"})
    assert exit_code == 0
    assert "BANANA_VALUE=1234" in stdout_list


def test_log_output_default(caplog):
    """
    By default each output line is logged as 'OUTPUT: <line>' at DEBUG level
    """
    with caplog.at_level(logging.DEBUG, logger="QESAP"):
        exit_code, _ = subprocess_run('echo "Banana"')
    assert exit_code == 0
    records = [rec for rec in caplog.records if rec.message == "OUTPUT: Banana"]
    assert len(records) == 1
    assert records[0].levelno == logging.DEBUG


def test_log_output_false(caplog):
    """
    With log_output=False the output lines are returned but not logged
    """
    with caplog.at_level(logging.DEBUG, logger="QESAP"):
        exit_code, stdout_list = subprocess_run('echo "Banana"', log_output=False)
    assert exit_code == 0
    assert stdout_list == ["Banana"]
    assert not any("OUTPUT:" in rec.message for rec in caplog.records)


def test_log_output_lines_level(caplog):
    """
    log_output_lines logs at DEBUG for a zero exit code, at ERROR otherwise
    """
    with caplog.at_level(logging.DEBUG, logger="QESAP"):
        log_output_lines(0, ["good"])
        log_output_lines(1, ["bad"])
    levels = {rec.message: rec.levelno for rec in caplog.records}
    assert levels["OUTPUT: good"] == logging.DEBUG
    assert levels["OUTPUT: bad"] == logging.ERROR
