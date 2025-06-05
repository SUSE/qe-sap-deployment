"""
configuration file related libraries
"""

import re
import os
import logging

log = logging.getLogger("QESAP")


def yaml_to_tfvars_entry(key, value):
    """
    Apply the proper conversion when moving
    variables from the YAML to the tfvars
    """

    # ref: https://developer.hashicorp.com/terraform/language/expressions/types#strings
    #      and https://developer.hashicorp.com/terraform/language/expressions/strings
    if isinstance(value, str):
        log.debug("Value '%s' detected as str.", value)
        entry = f'{key} = "{value}"'
    # ref: https://developer.hashicorp.com/terraform/language/expressions/types#numbers
    elif isinstance(value, int) and not isinstance(value, bool):
        log.debug("Value '%s' detected as int.", value)
        entry = f"{key} = {value}"
    elif isinstance(value, bool):
        log.debug("Value '%s' detected as bool.", value)
        entry = f"{key} = {str(value).lower()}"
    elif isinstance(value, list):
        log.debug("Value '%s' detected as list.", value)
        entry = '", "'.join(value)
        entry = f'{key} = ["{entry}"]'
    elif isinstance(value, dict):
        log.debug("Value '%s' detected as dict.", value)
        param_value = ""
        for dict_key, dict_value in value.items():
            param_value = f'{param_value}\t{dict_key} = "{dict_value}"\n'
        entry = f"{key} = {{\n" f"{param_value}" f"}}"
    else:
        log.error("Unrecognized value type in yaml file: %s = %s", key, value)
        return None
    return entry


def validate_ansible_hana_var(hana_var):
    """
    Validate hana_vars
    """
    mandatory = [
        ("sap_hana_install_software_directory", lambda value: re.search(r"/.*", value)),
        ("sap_hana_install_master_password", None),
        (
            "sap_hana_install_sid",
            lambda value: len(hana_var["sap_hana_install_sid"]) == 3,
        ),
        (
            "sap_hana_install_instance_number",
            lambda value: re.search(r"^[0-9]{2}$", value),
        ),
        ("sap_domain", None),
        ("primary_site", None),
        ("secondary_site", None),
    ]
    for mandatory_value in mandatory:
        if mandatory_value[0] not in hana_var:
            log.error("Mandatory %s not present in 'hana_var'", mandatory_value[0])
            return False
        if mandatory_value[1] is not None:
            if not mandatory_value[1](hana_var[mandatory_value[0]]):
                log.error(
                    "Invalid value '%s':%s",
                    mandatory_value[0],
                    hana_var[mandatory_value[0]],
                )
                return False
    return True


class CONF:
    """
    Class to manipulate data from the config.yaml
    """

    def __init__(self, configure_data):
        self.conf = configure_data

    def get_terraform_bin(self):
        """
        Allow to specify a custom binary to be used in place of terraform.
        Could be maybe used to give a try to opentofu.
        """
        if "bin" in self.conf["terraform"]:
            return self.conf["terraform"]["bin"]
        # The user does not specify any custom binary in its config.yaml
        # just return a generic binary name and let the OS to find it
        # in its way (PATH env var)
        return "terraform"

    def yaml_to_tfvars(self):
        """
        Takes data structure collected from the terraform part
        of the yaml config, converts it to tfvars format

        Returns:
            str: terraform.tfvars content string. None for error.
        """
        config_out = ""
        terraform_variables = self.conf["terraform"]["variables"]
        log.debug("terraform_variables:%s", terraform_variables)
        for key, value in terraform_variables.items():
            entry = yaml_to_tfvars_entry(key, value)
            if entry is None:
                return None
            config_out += f"\n{entry}"
        log.debug("config_out:%s", config_out)
        return config_out

    def terraform_yml(self):
        """
        Check if Terraform:variables are present in the config.yaml
        """
        if not self.conf:
            log.error("No configure data")
            return False

        if "terraform" not in self.conf:
            log.error("Missing 'terraform' key in configure data")
            return False

        if self.conf["terraform"] is None:
            log.error("conf['terraform'] is empty")
            return False

        if "variables" not in self.conf["terraform"]:
            log.error("Missing 'variables' key in conf['terraform'] ")
            return False

        if not isinstance(self.conf["terraform"]["variables"], dict):
            log.error("'variables' in conf['terraform'] is empty")
            return False

        return True

    def has_tfvar_template(self):
        """
        Search for terraform template conf.yaml region
        """
        if "terraform" not in self.conf or self.conf["terraform"] is None:
            log.info("No 'terraform' in the config.yaml")
            return False
        if "tfvars_template" not in self.conf["terraform"]:
            log.info("No 'tfvars_template' in the config.yaml")
            return False
        if not os.path.isfile(self.conf["terraform"]["tfvars_template"]):
            log.error(
                "File 'tfvars_template' %s does not exist.",
                self.conf["terraform"]["tfvars_template"],
            )
            return False
        return self.conf["terraform"]["tfvars_template"]

    def template_to_tfvars(self, tfvars_template):
        """
        Takes data structure collected from yaml config.
        Values are converted into tfvars format and checked against terraform.tfvars.template.
        Variables from yaml config are overwritten by values from template file.
        Whatever .tfvars.template content is in the file, is copied in the final terraform.tfvars.
        This function only eventually care about strings that
        are in a valid terraform variable format like:

        ```
        aaa = bbb
        ```

        They are also copied in the final .tfvars. Eventually values for them is updated if
        same variable is also specified in the conf.yaml

        Args:
            tfvars_template (str): path to the tfvars template file

        Returns:
            bool: True(pass)/False(failure)
        """
        log.info("Read %s", tfvars_template)
        with open(tfvars_template, "r", encoding="utf-8") as filehandler:
            tfvar_content = [f"{line.rstrip()}\n" for line in filehandler.readlines()]
            log.debug("Template:%s", tfvar_content)

            if not self.terraform_yml():
                log.debug("No terraform variables in the configure.yaml to merge")
                return tfvar_content

            log.debug("Config has terraform variables")
            for key, value in self.conf["terraform"]["variables"].items():
                key_replace = False
                # Look for key in the template file content
                for index, line in enumerate(tfvar_content):
                    if re.search(rf"{key}\s*=.*", line):
                        log.debug(
                            "Replace template %s with [%s = %s]", line, key, value
                        )
                        tfvar_content[index] = yaml_to_tfvars_entry(key, value) + "\n"
                        key_replace = True
                # add the new key/value pair
                if not key_replace:
                    log.debug(
                        "[k:%s = v:%s] is not in the template, append it", key, value
                    )
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

    def has_ansible(self):
        """
        Check if the ansible conf.yaml region is present
        """
        return "ansible" in self.conf

    @staticmethod
    def validate_ansible_media_config(ansible_conf, apiver):
        """
        Validate the media part of the ansible configure.yaml
        """
        if apiver < 3:
            log.error("Apiver: %d is no longer supported", apiver)
            return False

        if "hana_media" not in ansible_conf or ansible_conf["hana_media"] is None:
            log.error("Missing or empty 'hana_media' in 'ansible' in the config")
            return False

        for media in ansible_conf["hana_media"]:
            match = re.search(r"^http[s]?://.*", media)
            if match:
                log.error("Media %s provided as full url. File name expected.", media)
                return False

        for var in ["az_storage_account_name", "az_container_name"]:
            if var not in ansible_conf:
                log.error(
                    "Missing '%s' in 'ansible' in the config: %s", var, ansible_conf
                )
                return False

        if "az_sas_token" not in ansible_conf and "az_key_name" not in ansible_conf:
            log.error("Both az_sas_token and az_key_name missing in the config")
            return False
        return True

    def has_ansible_playbooks(self, sequence):
        """
        Return True if the `sequence` has at least
        one playbook in it.
        """
        if (
            not self.has_ansible()
            or not sequence
            or sequence not in self.conf["ansible"]
            or self.conf["ansible"][sequence] is None
        ):
            log.error("No Ansible playbooks to play for sequence:%s", sequence)
            return False
        return True

    def get_playbooks(self, sequence):
        """
        Get list of playbooks
        """
        return self.conf['ansible'][sequence]

    def validate_ansible_config(self, sequence):
        """
        Validate the ansible part of the internal structure of the config.yaml
        """
        if not self.has_ansible():
            log.info("No Ansible section in the conf.yaml. Nothing to validate.")
            return True

        if self.conf["ansible"] is None:
            log.error("No content in the Ansible section in the conf.yaml")
            return False

        log.debug("Configure ansible part of data:%s", self.conf["ansible"])

        if not self.validate_ansible_media_config(
            self.conf["ansible"], self.conf["apiver"]
        ):
            log.error("Ansible media configuration")
            return False

        if sequence:
            if sequence not in self.conf['ansible'] or self.conf['ansible'][sequence] is None:
                log.error('No Ansible playbooks to play in %s for sequence:%s', self.conf['ansible'], sequence)
                return False

        if "hana_vars" in self.conf["ansible"] and not validate_ansible_hana_var(
            self.conf["ansible"]["hana_vars"]
        ):
            return False
        return True

    def validate_basedir(self, basedir):
        """
        Validate the file and folder structure of the main repository
        """
        terraform_dir = os.path.join(basedir, "terraform")
        result = {
            "terraform": terraform_dir,
            "provider": None,
            "tfvars_file": None,
        }
        if self.has_ansible():
            result["hana_media_file"] = None
            result["hana_vars_file"] = None

        if not os.path.isdir(terraform_dir):
            log.error("Missing %s", terraform_dir)
            return False
        result["provider"] = os.path.join(terraform_dir, self.conf["provider"])
        if not os.path.isdir(result["provider"]):
            log.error("Missing %s", result["provider"])
            return False

        if self.has_ansible():
            ansible_pl_vars_dir = os.path.join(basedir, "ansible", "playbooks", "vars")
            if not os.path.isdir(ansible_pl_vars_dir):
                log.error("Missing %s", ansible_pl_vars_dir)
                return False

        result["tfvars_file"] = os.path.join(result["provider"], "terraform.tfvars")
        if self.has_ansible():
            result["hana_media_file"] = os.path.join(
                ansible_pl_vars_dir, "hana_media.yaml"
            )
            result["hana_vars_file"] = os.path.join(
                ansible_pl_vars_dir, "hana_vars.yaml"
            )
        return result
