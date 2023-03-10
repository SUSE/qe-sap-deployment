# qe-sap-deployment

This project aims to provide automation that will create highly-available SAP deployment to aide cluster testing.

This project is in a very early stage of development.

## Prerequisite

Tools needed

* Python 3.9
* terraform v1.3.6
* ansible 6.5.0 (ansible-core 2.13.5). Please refer to the **requirements.txt** file
* cloud provider cli tools (`az`, `aws`, `gcloud`)

The Python requirements could be managed with a virtual environment

```shell
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Prepare a ssh key pair

```shell
cd <SECRET_FOLDER> 
ssh-keygen -f id_rsa_cloud -t rsa -b 4096 -N
ssh-add id_rsa_cloud
```

## Usage

### Build and Destroy Terraform and Ansible components

To get started, the user must create a yml configuration file

```shell
cp config.yaml.example config.yaml
```

Edit the values of `config.yaml`:

Run the `config` step to get all the needed Terraform and Ansible configuration files generated.

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> configure
```

Terraform and Ansible deployment steps can be executed like:

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> terraform

(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> ansible
```

The destruction of the infrastructure, including the de-registration of SLES, can be conducted with:

```shell
(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> ansible -d

(venv) python3 scripts/qesap/qesap.py --verbose -c config.yaml -b <FOLDER_OF_YOUR_CLONED_REPO> terraform -d
```

### Manual terraform deployment

Here an example of Azure deployment

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
TF_LOG_PATH=terraform.destroy.log TF_LOG=INFO  terraform destroy
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
