"""
configuration file related libraries
"""
import logging
import re
import os

log = logging.getLogger('QESAPDEP')


def yaml_to_tfvars_entry(key, value):
    """
    Apply the proper conversion when moving
    variables from the YAML to the tfvars
    """
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
        log.error('Unrecognized value type in yaml file: %s = %s', key, value)
        return None
    return entry


def validate_ansible_hana_var(hana_var):
    """
    Validate hana_vars
    """
    mandatory = [('sap_hana_install_software_directory', lambda value: re.search(r'/.*', value)),
                 ('sap_hana_install_master_password', None),
                 ('sap_hana_install_sid', lambda value: len(hana_var['sap_hana_install_sid']) == 3),
                 ('sap_hana_install_instance_number', lambda value: re.search(r'^[0-9]{2}$', value)),
                 ('sap_domain', None)]
    for mandatory_value in mandatory:
        if mandatory_value[0] not in hana_var:
            log.error("Mandatory %s not present in 'hana_var'", mandatory_value[0])
            return False
        if mandatory_value[1] is not None:
            if not mandatory_value[1](hana_var[mandatory_value[0]]):
                log.error("Invalid value '%s':%s", mandatory_value[0], hana_var[mandatory_value[0]])
                return False
    return True


class CONF:
    """
    Class to manipulate data from the config.yaml
    """

    def __init__(self, configure_data):
        self.conf = configure_data

    def yaml_to_tfvars(self):
        """
        Takes data structure collected from yaml config,
        converts into tfvars format

        Returns:
            str: terraform.tfvars content string. None for error.
        """
        config_out = ''
        terraform_variables = self.conf['terraform']['variables']
        log.debug(self.conf)
        for key, value in terraform_variables.items():
            entry = yaml_to_tfvars_entry(key, value)
            if entry is None:
                return None
            config_out += f'\n{entry}'
        return config_out

    def terraform_yml(self):
        """
        Check if Terraform:variables are present in the config.yaml
        """
        if not self.conf:
            log.error("No configure data")
            return False

        if 'terraform' not in self.conf:
            log.error("Missing 'terraform' key in configure data")
            return False

        if self.conf['terraform'] is None:
            log.error("conf['terraform'] is empty")
            return False

        if 'variables' not in self.conf['terraform']:
            log.error("Missing 'variables' key in conf['terraform'] ")
            return False

        return True

    def template_to_tfvars(self, tfvars_template):
        """
        Takes data structure collected from yaml config.
        Values are converted into tfvars format and checked against terraform.tfvars.template.
        Variables from yaml config are overwritten by values from template file.

        Args:
            tfvars_template (str): path to the tfvars template file

        Returns:
            bool: True(pass)/False(failure)
        """
        log.info("Read %s", tfvars_template)
        with open(tfvars_template, 'r', encoding='utf-8') as filehandler:
            tfvar_content = [f"{line.rstrip()}\n" for line in filehandler.readlines()]
            log.debug("Template:%s", tfvar_content)

            if not self.terraform_yml():
                log.debug("No terraform variables in the configure.yaml to merge")
                return tfvar_content

            log.debug("Config has terraform variables")
            for key, value in self.conf['terraform']['variables'].items():
                key_replace = False
                # Look for key in the template file content
                for index, line in enumerate(tfvar_content):
                    if re.search(rf'{key}\s?=.*', line):
                        log.debug("Replace template %s with [%s = %s]", line, key, value)
                        tfvar_content[index] = f"{key} = {value}\n"
                        key_replace = True
                # add the new key/value pair
                if not key_replace:
                    log.debug("[k:%s = v:%s] is not in the template, append it", key, value)
                    entry = yaml_to_tfvars_entry(key, value)
                    if entry is None:
                        return None
                    tfvar_content.append(f"{entry}\n")
            log.debug("Result terraform.tfvars:\n%s", tfvar_content)
            return tfvar_content

    def validate(self):
        """
        Validate the mandatory and common part
        of the internal structure of the configure.yaml
        """
        log.debug("Configure data:%s", self.conf)
        if self.conf is None:
            log.error("Empty config")
            return False

        if "apiver" not in self.conf or not isinstance(self.conf["apiver"], int):
            log.error("Error at 'apiver' in the config")
            return False

        if "provider" not in self.conf or not isinstance(self.conf["provider"], str):
            log.error("Error at 'provider' in the config")
            return False

        return True

    def validate_ansible_config(self, sequence):
        """
        Validate the ansible part of the internal structure of the configure.yaml
        """
        log.debug("Configure data:%s", self.conf)

        if 'ansible' not in self.conf or self.conf['ansible'] is None:
            log.error("Error at 'ansible' in the config")
            return False

        if 'hana_urls' not in self.conf['ansible']:
            log.error("Missing 'hana_urls' in 'ansible' in the config")
            return False

        if sequence:
            if sequence not in self.conf['ansible'] or self.conf['ansible'][sequence] is None:
                log.error('No Ansible playbooks to play in %s for sequence:%s', self.conf['ansible'], sequence)
                return False

        if 'hana_vars' in self.conf['ansible']:
            if not validate_ansible_hana_var(self.conf['ansible']['hana_vars']):
                return False

        return True

    def validate_basedir(self, basedir):
        """
        Validate the file and folder structure of the main repository
        """
        terraform_dir = os.path.join(basedir, 'terraform')
        result = {
            'terraform': terraform_dir,
            'provider': None,
            'tfvars_file': None,
            'tfvars_template': None,
            'hana_media_file': None,
            'hana_vars_file': None
        }

        if not os.path.isdir(terraform_dir):
            log.error("Missing %s", terraform_dir)
            return False
        result['provider'] = os.path.join(terraform_dir, self.conf['provider'])
        if not os.path.isdir(result['provider']):
            log.error("Missing %s", result['provider'])
            return False
        tfvar_template_path = os.path.join(result['provider'], 'terraform.tfvars.template')
        # In case of template missing, it will be created from config.yaml
        if os.path.isfile(tfvar_template_path):
            result['tfvars_template'] = tfvar_template_path

        ansible_pl_vars_dir = os.path.join(basedir, 'ansible', 'playbooks', 'vars')
        if not os.path.isdir(ansible_pl_vars_dir):
            log.error("Missing %s", ansible_pl_vars_dir)
            return False

        result['tfvars_file'] = os.path.join(result['provider'], 'terraform.tfvars')
        result['hana_media_file'] = os.path.join(ansible_pl_vars_dir, 'hana_media.yaml')
        result['hana_vars_file'] = os.path.join(ansible_pl_vars_dir, 'hana_vars.yaml')

        return result
