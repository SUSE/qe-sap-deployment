# qe-sap-deployment

This project aims to provide automation that will create highly-available SAP deployment to aide cluster testing.

This project is in a very early stage of development.

## Prerequisite

Tools needed

* terraform v1.1.7
* ansible 4.10.0 (ansible-core 2.11.12)

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

The build and destroy scripts are still an early stage of development and represent the progress made so far. The scripts currently work for the 'azure' provider only.

To get started you must should create a new `variables.sh`:

```shell
cp variables.example variables.sh
```

Edit the values of variables.sh to match your configuration.

* PROVIDER : one of the folders in the terraform folder
* REG_CODE : SCC registration code used in the `registration.yaml` playbook
* EMAIL : email address used in the registration.yaml playbook
* SAPCONF : true/false

Copy the `terraform.tfvars.example` of the provided of your choice and configure it.

```shell
cp terraform/azure/terraform.tfvars.example terraform/azure/terraform.tfvars
```

Copy the `azure_hana_media.example.yaml` file and edit the values so that ansible knows where to download the installation media.  For Azure, it is preferred to upload the media to blobs in an Azure storage account.

```shell
cp ansible/playbooks/vars/azure_hana_media.example.yaml ansible/playbooks/vars/azure_hana_media.yaml
```

Once these steps are completed, it should be possible to run the `build.sh` script to create the infrastructure and install HANA on both VMs.

```shell
bash build.sh
```

The destruction of the infrastructure, including the de-registration of SLES, can be conducted with the `destroy.sh` script.

```shell
bash destroy.sh
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
