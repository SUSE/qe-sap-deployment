"""
configuration file related libraries
"""
import logging
import re

log = logging.getLogger('QESAPDEP')


def yaml_to_tfvars(yaml_data):
    """ Takes data structure collected from yaml config,
    converts into tfvars format and writes it into the final tfvars file

    Args:
        yaml_data (dict): data structure returned from is_yaml
        tfvars_file (str): path to the target tfvars file

    Returns:
        bool: True(pass)/False(failure)
    """
    config_out = ''
    terraform_variables = yaml_data['terraform']['variables']
    print(yaml_data)
    for key, value in terraform_variables.items():
        if isinstance(value, (str, int)):
            entry = f'{key} = "{str(value)}"'
        elif isinstance(value, bool):
            entry = f'{key} = "{str(value).lower()}"'
        elif isinstance(value, list):
            entry = '", "'.join(value)
            entry = f'{key} = ["{entry}"]'
        elif isinstance(value, dict):
            param_value = ''
            for dict_key, dict_value in value.items():
                param_value = f'{param_value}\t{dict_key} = "{dict_value}"\n'
            entry = f'{key} = {{\n' \
                    f'{param_value}' \
                    f'}}'
        else:
            log.error(f'Unrecognized value type in yaml file: {key} = {value}')
            return False
        config_out = f'{config_out}\n{entry}'

    return config_out


def terraform_yml(configure_data):
    """
    Check if Terraform:variables are present in the config.yaml
    """
    if not configure_data:
        return False

    if 'terraform' not in configure_data.keys():
        return False
    
    if configure_data['terraform'] is None:
        return False

    if 'variables' not in configure_data['terraform'].keys():
        return False

    return True



def template_to_tfvars(tfvars_template, configure_data):
    """ takes

    Args:
        configure_data (dict): configuration data structure
        tfvars_template (str): path to the tfvars template file

    Returns:
        bool: True(pass)/False(failure)
    """
    log.info("Read %s", tfvars_template)
    with open(tfvars_template, 'r') as f:
        tfvar_content = f.readlines()
        log.debug("Template:%s", tfvar_content)

        if terraform_yml(configure_data):
            log.debug("Config has terraform variables")
            for k,v in configure_data['terraform']['variables'].items():
                key_replace = False
                # Look for k in the template file content
                for index, line in enumerate(tfvar_content):
                    match = re.search(k+r'\s?=.*', line)
                    if match:
                        log.debug("Replace template %s with [%s = %s]", line, k, v)
                        tfvar_content[index] = f"{k} = {v}\n"
                        key_replace = True
                # add the new key/value pair
                if not key_replace:
                    log.debug("[k:%s = v:%s] is not in the template, append it", k, v)
                    tfvar_content.append(f"{k} = {v}\n")
        log.debug("Result terraform.tfvars:\n%s", tfvar_content)
        return tfvar_content
