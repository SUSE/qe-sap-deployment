import logging
import yaml

from qesap import cli


log = logging.getLogger(__name__)


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


def test_cli_configure_noargs(check_manadatory_args):
    '''
    configure subcommand at least needs:
    -b to know where to write the terraform.tfvars
    -c to know what to write in the terraform.tfvars
    '''
    assert check_manadatory_args(cli, 'configure')


def test_cli_configure_b_notexist(capsys, tmpdir):
    '''
    -b has to be an existing folder. The script
    user is in charge to create it in advance
    '''

    #Provide a valid config.yaml
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        yaml.dump({}, file)

    try:
        # Run with a not existing -b folder
        ret = cli(['-b', '/paperinik', '-c', config_file_name, 'configure'])
        assert ret
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert 'is not a folder' in captured.err


def test_cli_configure_c_notexist(capsys, tmpdir):
    '''
    -c has to be an existing file.
    '''
    try:
        cli(['-b', str(tmpdir), '-c', str(tmpdir / 'config.yml'), 'configure'])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert 'is not a file' in captured.err


def test_cli_configure_c_notyaml(capsys, tmpdir):
    '''
    -c has to be valid YAML
    '''
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        file.write("this: is: invalid")
    try:
        cli(['-b', str(tmpdir), '-c', config_file_name, 'configure'])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert 'is not a valid YAML file' in captured.err


def test_cli_configure(base_args, tmpdir):
    '''
    Test configure with minimal amount of arguments
    '''
    data = {'cane': 'pane'}
    config_file_name = str(tmpdir / 'config.yaml')
    with open(config_file_name, 'w', encoding='utf-8') as file:
        yaml.dump(data, file)
    args = base_args(base_dir=tmpdir, config_file=config_file_name)
    args.append('configure')
    p = cli(args)
    assert p.basedir == str(tmpdir)
    assert p.configfile == data


def test_cli_deploy(base_args):
    '''
    Test deploy with minimal amount of arguments
    '''
    args = base_args()
    args.append('deploy')
    cli(args)


def test_cli_destroy(base_args):
    '''
    Test destroy with minimal amount of arguments
    '''
    args = base_args()
    args.append('destroy')
    cli(args)


def test_cli_terraform_noargs(check_manadatory_args):
    '''
    terraform subcommand at least needs:
    -b to know where to look for the Terraform files to run
    -c to know the Cloud Provider subfolder to use
    '''
    assert check_manadatory_args(cli, 'terraform')


def test_cli_terraform(base_args):
    '''
    Test terraform with minimal amount of arguments
    '''
    args = base_args()
    args.append('terraform')
    cli(args)


def test_cli_terraform_destroy(base_args):
    '''
    Test terraform with -d to run destroy mode
    '''
    args = base_args()
    args.append('terraform')
    args.append('-d')
    cli(args)


def test_cli_ansible_noargs(check_manadatory_args):
    '''
    ansible subcommand at least needs:
    -b to know where to look for the Ansible playbooks
       to be played (and maybe the inventory).
    -c to know the list of Ansible Playbooks
       to play and other setting for them (like the SCC reg code)
    '''
    assert check_manadatory_args(cli, 'ansible')


def test_cli_ansible(base_args):
    '''
    Test ansible with minimal amount of arguments
    '''
    args = base_args()
    args.append('ansible')
    cli(args)
