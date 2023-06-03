import os
import re
import logging
import yaml

from qesap import main

log = logging.getLogger(__name__)


def test_configure_no_tfvars_template(args_helper, config_yaml_sample):
    '''
    if tfvars template is missing,
    just create tfvars from the config.yaml content
    '''
    provider = 'pinocchio'

    # create a dummy conf.yaml with some generic content
    # but without the 'tfvars_template'
    conf = config_yaml_sample(provider)

    # Create some regexp from the injected conf.yaml
    # to be used later in the verification
    # against the generated terraform.tfvars
    regexp_set = []
    conf_dict = yaml.safe_load(conf)

    # for each string variable in the config.yaml terraform::variables section ...
    for key, value in conf_dict['terraform']['variables'].items():
        if isinstance(value, str):
            # ... create a regexp to match the expected translation
            # in the result .tfvars file
            # Each key/value pair has to be translated with an = in the middle
            # and eventually some spaces
            regexp_set.append(rf'{key}\s*=\s*"{value}"')

    # prepare the `qesap.py configure` command line
    args, tfvar_path, *_ = args_helper(provider, conf)
    args.append('configure')
    tfvar_file = os.path.join(tfvar_path, 'terraform.tfvars')

    assert main(args) == 0

    # now check the content of the generated .tfvars
    assert os.path.isfile(tfvar_file)
    with open(tfvar_file, 'r', encoding="utf-8") as file:
        tfvars_lines = file.readlines()
        for var_re in regexp_set:
            one_match = 0
            for line in tfvars_lines:
                if not one_match:
                    match = re.search(var_re, line)
                    if match:
                        log.debug("Line [%s] match with [%s]", line, var_re)
                        one_match += 1
            assert one_match == 1, 'Variable:' + var_re + ' match ' + one_match + ' times in the generated terraform.tfvars'


def test_configure_create_tfvars_file(configure_helper, config_yaml_sample):
    """
    Test that 'configure' write a terraform.tfvars file in
    <BASE_DIR>/terraform/<PROVIDER>
    """
    provider = 'pinocchio'
    conf = config_yaml_sample(provider)
    args, tfvar_file, *_ = configure_helper(provider, conf, None)

    assert main(args) == 0

    assert os.path.isfile(tfvar_file)


def test_configure_tfvars_novariables_notemplate(config_yaml_sample_for_terraform, configure_helper):
    """
    If no terraform.tfvars.template is present and
    no terraform::variables is present in the config.yaml
    it has to fails.
    """
    provider = 'pinocchio'
    conf = config_yaml_sample_for_terraform('', provider)

    args, *_ = configure_helper(provider, conf, None)

    assert main(args) == 1


def test_configure_not_existing_template(config_yaml_sample_for_terraform, configure_helper, tmpdir):
    """
    Test scenario: the config.yaml has a tfvars_template but the file does not exist;
    at the same time the same conf.yaml has not terraform:variables section.
    """
    provider = 'pinocchio'
    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = [
        "something = static\n",
        "hananame = hahaha\n",
        "ip_range = 10.0.4.0/24\n"]

    terraform_section = '''terraform:
    tfvars_template: melampo
'''
    conf = config_yaml_sample_for_terraform(terraform_section, provider)
    args, tfvar_path, *_ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 1


def test_configure_tfvars_novariables(config_yaml_sample_for_terraform, configure_helper, tmpdir):
    """
    Test that 'configure' generated terraform.tfvars file
    content is like terraform.tfvars.template
    if no variables are provided in the config.yaml
    """
    provider = 'pinocchio'

    # define template file
    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = [
        "something = static\n",
        "hananame = hahaha\n",
        "ip_range = 10.0.4.0/24\n"]

    # define terraform section in the conf.yaml
    # add parameter to point to the template file
    terraform_section = f'''terraform:
    tfvars_template: {tfvar_template['file']}
'''
    conf = config_yaml_sample_for_terraform(terraform_section, provider)
    args, tfvar_path, *_ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    with open(tfvar_path, 'r', encoding='utf-8') as file:
        data = file.readlines()
        assert tfvar_template['data'] == data


def test_configure_tfvars_with_variables(config_yaml_sample_for_terraform, configure_helper, tmpdir):
    """
    Test that 'configure' generated terraform.tfvars file
    content is like terraform.tfvars.template
    plus all key/value pairs from the variables section in
    the config.yaml
    """
    provider = 'pinocchio'
    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = [
        "something = static\n",
        "hananame = hahaha\n",
        "ip_range = 10.0.4.0/24"]
    terraform_section = f'''terraform:
  tfvars_template: {tfvar_template['file']}
  variables:
    region : eu1
    deployment_name : "rocket"
'''
    conf = config_yaml_sample_for_terraform(terraform_section, provider)
    args, tfvar_path, *_ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    expected_tfvars = tfvar_template['data'][0:2]
    # EOL is expected to be added in terraform.tfvars
    # if missing at the end of the template
    expected_tfvars.append(tfvar_template['data'][2] + '\n')
    expected_tfvars.append('region = "eu1"\n')
    expected_tfvars.append('deployment_name = "rocket"\n')
    with open(tfvar_path, 'r', encoding='utf-8') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_tfvars_template_spaces(config_yaml_sample_for_terraform, configure_helper, tmpdir):
    """
    Test that python code support different kind of spaces in the .template
    """
    provider = 'pinocchio'
    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = [
        "basic = bimbumbam\n",
        "extra_space_before      = bimbumbam\n",
        "extra_space_after =       bimbumbam\n",
        "extra_space_both    =     bimbumbam"]
    terraform_section = f'''terraform:
  tfvars_template: {tfvar_template['file']}
  variables:
    region : eu1
    deployment_name : "rocket"
'''
    conf = config_yaml_sample_for_terraform(terraform_section, provider)
    args, tfvar_path, *_ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    expected_tfvars = tfvar_template['data'][0:3]
    # EOL is expected to be added in terraform.tfvars
    # if missing at the end of the template
    expected_tfvars.append(tfvar_template['data'][3] + '\n')
    expected_tfvars.append('region = "eu1"\n')
    expected_tfvars.append('deployment_name = "rocket"\n')
    with open(tfvar_path, 'r', encoding='utf-8') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_tfvars_string_commas(config_yaml_sample_for_terraform, configure_helper, tmpdir):
    """
    Terraform.tfvars need commas around all strings variables
    """
    provider = 'pinocchio'
    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = ["something = static"]
    terraform_section = f'''
terraform:
  tfvars_template: {tfvar_template['file']}
  variables:
    region : eu1
    deployment_name : "rocket"
    os_image: SUSE:sles-sap-15-sp3-byos:gen2:2022.05.05
    public_key: /root/secret/id_rsa.pub
'''
    conf = config_yaml_sample_for_terraform(terraform_section, provider)
    args, tfvar_path, *_ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    # EOL is expected to be added in terraform.tfvars
    # if missing at the end of the template
    expected_tfvars = [
        tfvar_template['data'][0] + '\n',
        'region = "eu1"\n',
        'deployment_name = "rocket"\n',
        'os_image = "SUSE:sles-sap-15-sp3-byos:gen2:2022.05.05"\n',
        'public_key = "/root/secret/id_rsa.pub"\n'
    ]
    with open(tfvar_path, 'r', encoding='utf-8') as file:
        data = file.readlines()
        assert expected_tfvars == data


def test_configure_tfvars_overwrite_variables(config_yaml_sample_for_terraform, configure_helper, tmpdir):
    """
    Test 'configure' generated terraform.tfvars file:
    if same key pair is both in the terraform.tfvars.template
    and config.yaml, the YAML content win
    """
    provider = 'pinocchio'

    tfvar_template = {}
    tfvar_template['file'] = tmpdir / 'terraform.template.tfvar'
    tfvar_template['data'] = [
        'something = static\n',
        'somethingelse = keep\n']

    terraform_section = f'''
terraform:
  tfvars_template: {tfvar_template['file']}
  variables:
    something : yamlrulez'''
    conf = config_yaml_sample_for_terraform(terraform_section, provider)
    args, tfvar_path, *_ = configure_helper(provider, conf, tfvar_template)

    assert main(args) == 0

    expected_tfvars = [
        'something = "yamlrulez"\n',
        'somethingelse = keep\n']
    with open(tfvar_path, 'r', encoding='utf-8') as file:
        data = file.readlines()
        assert expected_tfvars == data
