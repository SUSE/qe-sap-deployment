from qesap import cli


def test_cli_help(capsys):
    '''
    Check that --help prints an help message
    '''
    try:
        cli(['--help'])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    result = captured.out
    assert "usage:" in result


def test_cli_configure_noargs(capsys):
    '''
    Test configure subcommand but without to provide
    any argument
    '''
    try:
        cli(['configure'])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert 'error:' in captured.err


def test_cli_configure_o_notexist(capsys):
    '''
    -o has to be an existing folder. The script
    user is in charge to create it in advance
    '''
    try:
        cli(['configure', '-o', '/paperinik'])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert 'error:' in captured.err


def test_cli_configure(tmpdir):
    '''
    Test configure with minimal amount of arguments
    '''
    p = cli(['-b', str(tmpdir), 'configure'])
    assert p.basedir == str(tmpdir)


def test_cli_deploy(tmpdir):
    '''
    Test deploy with minimal amount of arguments
    '''
    cli(['-b', str(tmpdir), 'deploy'])


def test_cli_destroy(tmpdir):
    '''
    Test destroy with minimal amount of arguments
    '''
    cli(['-b', str(tmpdir), 'destroy'])


def test_cli_terraform(tmpdir):
    '''
    Test terraform with minimal amount of arguments
    '''
    cli(['-b', str(tmpdir), 'terraform'])


def test_cli_ansible(tmpdir):
    '''
    Test ansible with minimal amount of arguments
    '''
    cli(['-b', str(tmpdir), 'ansible'])
