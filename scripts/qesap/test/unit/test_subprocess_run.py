from qesap import subprocess_run


def test_no_command():
    '''
    Run subprocess_run providing no commands
    result in an error
    '''
    exit_code, stdout_list = subprocess_run([])
    assert exit_code == 1
    assert stdout_list == []


def test_echo():
    '''
    Run subprocess_run using the true subprocess
    '''
    test_text = '"Banana"'
    exit_code, stdout_list = subprocess_run(['echo', test_text])
    assert exit_code == 0
    assert stdout_list == [test_text]


def test_multilines():
    '''
    each stdout line has to be in a different stdout array element
    '''
    str_list = ['a', 'b', 'c']
    test_text = ''
    for s in str_list:
        test_text += (s * 10) + "\n"
    _, stdout_list = subprocess_run(['echo', test_text])
    assert len(stdout_list) == len(str_list) + 1
    for i, line in enumerate(str_list):
        assert line * 10 == stdout_list[i].strip()


def test_stderr():
    '''
    Run subprocess_run redirect the stderr only on the log
    '''
    test_text = '"Banana"'
    exit_code, stdout_list = subprocess_run(['logger', '-s', test_text])
    assert exit_code == 0
    assert stdout_list == []


def test_err():
    '''
    Run subprocess_run with a command that fails
    '''
    not_existing_file = '"Banana"'

    exit_code, stdout_list = subprocess_run(['cat', not_existing_file])
    assert exit_code == 1
    assert stdout_list == []
