# qe-sap-deployment

This project aims to provide automation that will create highly-available SAP deployment to aide cluster testing.

This project is in a very early stage of development.

## Prerequisite

Tools needed

* Python >= 3.10
* terraform v1.5.7
* ansible-core 2.16.8 : please refer to the **requirements.txt** file
* cloud provider cli tools (`az`, `aws`, `gcloud`)

The Python requirements could be managed with a virtual environment

```shell
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Ansible dependency are managed separately. After the installation of the Ansible core the following command has to be executed:

```shell
ansible-galaxy install -r requirements.yml
```

Prepare a ssh key pair

```shell
cd <SECRET_FOLDER>
ssh-keygen -f id_rsa_cloud -t rsa -b 4096 -N
ssh-add id_rsa_cloud
```

## Usage

### Qesap driven deployment

This project provides a script in `scripts/qesap/qesap.py` to drive the deployment, attempting to hide the complexity of the underlying Terraform and Ansible scripts and commands.

#### Configuration file

To get started, the user must create a yaml configuration file

```shell
cp config.yaml.example config.yaml
```

Edit the values of `config.yaml`:

Run the `config` step to get all the needed Terraform and Ansible configuration files generated.

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> configure
```

##### Generic settings

Two main global settings are:

* **provider** : refer to the cloud provider name. Has to be one of the folder names in `terraform/`
* **apiver** : refer to the config.yaml format. Qesap.py could use this number to attempt some behavioral adaptation.

##### Terraform settings

The main section is `terraform::variables`. All the fields there are translated in the `terraform.tfvar`. For example

```yaml
provider: azure
apiver: 3
terraform:
    variables:
        deploy_name: something
        region: europe
```

result in a `terraform/azure/terraform.tfvars` generated file like:

```bash
deploy_name = "something"
region = "europe"
```

To mitigate code duplication in the terraform section across multiple different conf.yaml, the user can use so called Terraform tfvars templates.

The used can create a file like `/home/user/terraform.template.tfvars` that is expected to use same syntax of tfvar files.

User has to refer to it with `tfvars_template` setting in the conf.yaml

```yaml
provider: azure
apiver: 3
terraform:
    tfvars_template: /home/user/terraform.template.tfvars
```

The generated `terraform.tfvars` file will get values from the template.

If the conf.yaml also have a `terraform::variables` section, values from that will be used too.
In case of collision with setting in both the conf.yaml and in the template, values from the conf.yaml will win.

By default the deployment will use whatever terraform binary is available on the system. It is possible to specify a custom binary using `terraform:bin` key:

```yaml
provider: azure
apiver: 3
terraform:
    bin: /home/user/bin/version000/terraform
```

##### Ansible settings

The Ansible playbooks needs some .yaml configuration files. Some of them are generated by Terraform, some of them has to be provided by the user. The **qesap.py** `configure` command can support the user to create them.

###### Hana variables

The Ansible project requires a configuration file `ansible/playbooks/vars/hana_vars.yaml`. This file is generated from the `ansible::hana_vars` section of the config.yaml. All the content of the `hana_vars` config.yaml section is directly written in the hana_vars.yaml:

```yaml
provider: azure
apiver: 3
ansible:
  hana_vars:
    sap_hana_install_software_directory: /hana/shared/install
    sap_hana_install_master_password: 'SomeSecret'
    sap_hana_install_sid: 'HDB'
    sap_hana_install_instance_number: '00'
    sap_domain: "qe-test.example.com"
    primary_site: 'goofy'
    secondary_site: 'miky'
```

Required fields in this section are documented in the qe-sap-deployment ansible documentation.

###### Hana media

The Ansible project is provided with a playbook `sap-hana-download-media.yaml` to get the Hana installers. This playbook is configured using an Ansible variables file named `hana_media.yaml`. The `qesap.py` script can assit the user to generate it as part of `configure` step. Exactly these fields of the conf.yaml are needed to generate the `hana_media.yaml` file.

```yaml
ansible:
  az_storage_account_name: "something"
  az_container_name:  "somewhere"
  az_sas_token: "secret***token"
  hana_media:
    - "SOMETHING.EXE"
    - "SOMETIME.SAR"
    - "SOMEWHERE.SAR"
```

Refer to the qe-sap-deployment Ansible documentation or `ansible/playbooks/vars/hana_media.example.yaml` for more details about these settings.

###### Playbooks sequence

The `qesap.py ... ansible` sub-command calls a sequence of playbooks execution.
By default the sequence is from the `ansible::sequences::create` section of the config.yaml.
The `ansible::sequences::destroy` sequence is used by `qesap.py ... ansible -d`
It is also possible to request the execution of a specific sequence using
`qesap.py ... ansible -s somethingelse`.

```yaml
apiver: 4
ansible:
  sequences:
    create:
      - registration.yaml -e reg_code=******* -e email_address=your@email.some
      - pre-cluster.yaml
      - sap-hana-preconfigure.yaml -e use_sapconf=true
      - cluster_sbd_prep.yaml
      - sap-hana-storage.yaml
      - sap-hana-download-media.yaml
      - sap-hana-install.yaml
      - sap-hana-system-replication.yaml
      - sap-hana-system-replication-hooks.yaml
      - sap-hana-cluster.yaml
    somethingelse:
      - some-other-playbook.yaml
    destroy:
      - deregister.yaml
```

* In case of Azure deployment using native fencing, there are additional parameters to be added for `sap-hana-cluster.yaml` playbook.
* For details please check ./docs/playbooks/README.md

#### Deploy

Terraform and Ansible deployment steps can be executed like:

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> deploy
````

That is equivalent to

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> terraform

(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> ansible -s create
```

The terraform sub command has a partial support for Terraform workspace

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> terraform -w my_workspace
```

#### Destroy

The destruction of the infrastructure, including the de-registration of SLES, can be conducted with:

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> destroy
```

That is equivalent to

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> ansible -d

(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> terraform -d
```

### Manual deployment

It is possible to use the deployment, without using the `qesap.py` script.
A possible way to get the proper sequence of terraform and ansible commands to run, is obtaining them from `qesap.py` using the `--dryrun` mode.

Here is an example of a sequence of Terraform commands to obtain the Azure deployment

```shell
cd terraform/azure
TF_LOG_PATH=terraform.plan.log TF_LOG=INFO terraform plan -out=plan.zip
TF_LOG_PATH=terraform.apply.log TF_LOG=INFO terraform apply -auto-approve plan.zip
```

Terraform also generate the Ansible inventory file **inventory.yaml**

Test the inventory by pinging all hosts

```shell
ansible -i inventory.yaml all -m ping --ssh-extra-args="-o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new -i <SECRET_FOLDER>/id_rsa_cloud" -u cloudadmin
```

Destroy the deployed infrastructure

```shell
cd terraform/azure
TF_LOG_PATH=terraform.destroy.log TF_LOG=INFO terraform destroy
```

### Run deployment in a container

Dockerfile provided to keep track of right version of all needed. It need to be build once:

```shell
podman pull opensuse/tumbleweed:latest
podman build -t my-tag .
```

The image expect this repository code to be mount in **/src**

Cloud provider account can be managed:

* from within the image (e.g running `az login` from within the image)
* share already existing sessions by mounting proper folders `-v ~/.aws:/root/.aws  -v ~/.azure:/root/.azure  -v ~/.config/gcloud:/root/.config/gcloud`

Existing ssh keys has to be mounted `-v $(pwd)/secret:/root/.ssh`

The image can be used interactively

```shell
cd <THIS_REPO_FOLDER>
podman run -it -v .:/src -v ~/.azure:/root/.azure -v $(pwd)/secret:/root/.ssh
```

Or to execute a specific action:

```shell
cd <THIS_REPO_FOLDER>
podman run -it \
    -v .:/src -v ~/.azure:/root/.azure -v $(pwd)/secret:/root/.ssh my-tag \
    python3 /src/scripts/qesap/qesap.py --verbose -c config.yaml -b /src terraform
    python3 /src/scripts/qesap/qesap.py --verbose -c config.yaml -b /src ansible
```

### Using roles from a different repo

To use roles located in a different repository manually, just copy the desired role directory in `ansible/roles`, and call it from a playbook within the `roles:` section. An example of how to fetch and use a role can be found in `ansible/playbooks/registration_role`.

If the user does not wish to copy the role in the `roles` folder of this repository, it is possible by adding the directory inside which the desired role is located in the environmental variable `$ANSIBLE_ROLES_PATH` before running the deployment.

```shell
export ANSIBLE_ROLES_PATH=<the-dir-where-the-role-is-located>
. . . (run deployment as you would normally do)
```

### Mark temporary workaround for known issues

If Ansible code is added to temporary workaround known issue, already associated to an open ticket, there's a convention to communicate it to openQA.
Use `ansible.builtin.debug` with a specific format.

```yaml
msg: "[OSADO][softfail] [bsc or jsc]#[number] [short description]"
```

Here a complete example:

```yaml
- name: Example of debug message
      ansible.builtin.debug:
        msg: "[OSADO][softfail] bsc#123456789 Here a generic message with some explanations."
```
