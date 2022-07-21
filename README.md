# qe-sap-deployment

This project aims to provide automation that will create highly-available SAP deployment to aide cluster testing.

This project is in a very early stage of development.

## Prerequisite
Tools needed
- terraform v1.1.7
- ansible 4.10.0 (ansible-core 2.11.12)

The Python requirements could be managed with a virtual environment
```
$ python3 -m venv venv
$ source vanv/bin/activate
$ pip install -r requirements.txt
```

Prepare a ssh key pair
```
$ cd <SECRET_FOLDER> 
$ ssh-keygen -f id_rsa_cloud -t rsa -b 4096 -N
```

## Usage
Here an example of Azure deployment
```
$ cd terraform/azure
$ TF_LOG_PATH=terraform.plan.log TF_LOG=INFO  terraform plan -out=plan.zip
$ TF_LOG_PATH=terraform.apply.log TF_LOG=INFO  terraform apply -auto-approve plan.zip
```

Collect the output and generate the the inventory
```
$ cd terraform/azure
$ terraform output --json > azure.json
$ python3 ../../scripts/out2inventory.py -s azure.json -o azure.yaml
```

Test the inventory by pinging all hosts 
```
$ ansible -i azure.yaml all -m ping --ssh-extra-args="-o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new -i <SECRET_FOLDER>/id_rsa_cloud" -u cloudadmin
```

Destroy the deployed infrastructure
```
$ cd terraform/azure
$ TF_LOG_PATH=terraform.destroy.log TF_LOG=INFO  terraform destroy
 ```
