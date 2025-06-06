# AWS Public Cloud deployment with Terraform and Ansible

* [Quickstart](#quickstart)
* [High level description](#high-level-description)
* [Customization](#customization)
  * [Use already existing network resources](#use-already-existing-network-resources)
  * [Autogenerated network addresses](#autogenerated-network-addresses)
* [Advanced Customization](#advanced-customization)
  * [Terraform Parallelism](#terraform-parallelism)
  * [Remote State](#remote-state)
  * [AWS catalog images](#aws-catalog-images)
  * [How to upload a custom image](#how-to-upload-a-custom-image)
* [Troubleshooting](#troubleshooting)

This sub directory contains the cloud specific part for usage of this
repository with Amazon Web Services (AWS). Looking for another
provider? See [Getting started](../README.md#getting-started)

## Quickstart

This is a very short guide. For detailed information see
[Using SUSE Automation to Deploy an SAP HANA Cluster on AWS - Getting Started🔗](https://documentation.suse.com/sbp/all/single-html/TRD-SLES-SAP-HA-automation-quickstart-cloud-aws/).

For detailed information and deployment options have a look at `terraform.tfvars.example`.

1) **Rename terraform.tfvars:**

    ``` shell
    mv terraform.tfvars.example terraform.tfvars
    ```

    Now, the created file must be configured to define the deployment.

    **Note:** Find some help in for IP addresses configuration below in [Customization](#customization).

2) **Generate private and public keys for the cluster nodes without specifying the passphrase:**

    ``` shell
    mkdir -p ../sshkeys
    ssh-keygen -f ../sshkeys/cluster.id_rsa -q -P ""
    ```

    The key files need to have same name as defined in [terraform.tfvars](./terraform.tfvars.example).

3) **Configure API access to AWS**

    A pair of AWS API access key and secret key will be required;

    there are several ways to configure the keys:

    * env. variables

    ``` shell
    export AWS_ACCESS_KEY_ID="<HERE_GOES_THE_ACCESS_KEY>"
    export AWS_SECRET_ACCESS_KEY="<HERE_GOES_THE_SECRET_KEY>"
    export AWS_DEFAULT_REGION="eu-central-1"
    terraform plan
    ```

    * AWS credentials

    Refer to terraform AWS provider documentation.
    Same configuration needed to use `aws` command line tool applies to terraform too.
    So it can be created with the command: `aws configure`.

    **Note**: All tests so far with this configuration have been done with only the keys stored in the credentials files, and the region being passed as a variable.

    * AWS user authorizations

    In order to execute the deployment properly using terraform, the used user must have some policies enabled. Mostly, it needs access to manage EC2 instances, S3 buckets, IAM (to create roles and policies) and EFS storage.

    In order to setup the IAM proper rights, 2 options are available:

    1. Set the `IAMFullAccess` policy to the user running the project (or to the group which the user belongs to).
        This is not recommended as this IAM policy give full IAM access to the user.
    2. A better and more secure option, is to create a new policy to give access to create roles with rights to only manage EC2 instances. This will make the project executable, but won't set any other IAM permission to the users. This option is the recommended one. To use this approach, create the next policy giving a meaningful name (`TerraformIAMPolicies` for example) and attach it to the users that will run the project (or the group the users belong to):

        ``` json
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "iam:CreateServiceLinkedRole",
                        "iam:PassRole",
                        "iam:CreateRole",
                        "iam:TagRole",
                        "iam:GetRole",
                        "iam:DeleteRole",
                        "iam:GetRolePolicy",
                        "iam:PutRolePolicy",
                        "iam:DeleteRolePolicy",
                        "iam:ListInstanceProfilesForRole",
                        "iam:CreateInstanceProfile",
                        "iam:GetInstanceProfile",
                        "iam:RemoveRoleFromInstanceProfile",
                        "iam:DeleteInstanceProfile",
                        "iam:AddRoleToInstanceProfile"
                    ],
                    "Resource": "*"
                }
            ]
        }
        ```

    The policy must be attached only to the `IAM` service if it's created manually and
    not with the json inline option.

    Here how it should look like your user or group:

    ![AWS policies](./images/policies.png)

    **Warning: If you use the 2nd option, the AWS web panel won't show that the created instances have any role attached, but they have. The limits in the IAM access makes this not visible, that's all.**

4) **Deploy**

    ``` shell
    terraform init
    terraform workspace new myexecution # optional
    terraform workspace select myexecution # optional
    terraform plan
    terraform apply
    ```

    To get rid of the deployment, destroy the created infrastructure with:

    ``` shell
    terraform destroy
    ```

## High level description

This Terraform configuration files in this directory can be used to create the infrastructure required to install a SAP HanaSR cluster in System Replication mode, combined with the high-availability capabilities provided by the SUSE Linux Enterprise Server for SAP Applications in *AWS*.

![High level description](../doc/highlevel_description_aws.png)

The infrastructure deployed includes:

* Virtual Private Cloud (VPC) network
* subnets within the VPC network
* A security group with rules for access to the instances created in the subnet.
Only allowed external network traffic is for the protocols: SSH, HTTP, HTTPS, and for the HAWK service.
Internally to the subnet, all traffic is allowed.
* public IP Addresses
* route tables
* IAM Roles
* EC2 instances
* EBS disks
* shared EFS file systems
* SSH key pairs

By default, this configuration creates 3 instances in AWS: one for support services (mainly iSCSI as most other services - DHCP, NTP, etc - are provided by Amazon) and 2 cluster nodes, but this can be changed to deploy more cluster nodes as needed.

Once the infrastructure is created by Terraform, the servers can be provisioned with Ansible.

## Customization

In order to deploy the environment, different configurations are available through the terraform variables. These variables can be configured using a `terraform.tfvars` file. An example is available in [terraform.tfvars.example](./terraform.tvars.example). To find all the available variables check the [variables.tf](./variables.tf) file.

### Use already existing network resources

The usage of already existing network resources (vpc and security groups) can be done configuring the `terraform.tfvars` file and adjusting some variables. The example of how to use them is available at [terraform.tfvars.example](terraform.tfvars.example).

**Important: In order to use the deployment with an already existing vpc, it must have an internet gateway attached.**

### Relevant Details

There are some fixed values used throughout the terraform configuration:

* The private IP address of the iSCSI server is set to 10.0.0.254.
* The cluster nodes are created with private IPs starting with 10.0.1.0 and on. The instance running with 10.0.1.0 is used initially as the master node of the cluster, ie, the node where `ha-cluster-init` is run.
* The iSCSI server has a second disk volume that is being used as a shared device.
* Salt is partitioning this device in 5 x 1MB partitions and then configuring just the LUN 0 for iSCSI (improvement is needed in iscsi-formula to create more than one device). **Until this improvement is added, an iSCSI config file (**`/etc/target/saveconfig.json`**) is loaded when the qa_mode is set to true to configure 5 more LUN, mandatory for other tests like DRBD.**
* iSCSI LUN 0 is being used in the cluster as SBD device.
* The cluster nodes have a second disk volume that is being used for HANA installation.

### Autogenerated network addresses

The assignment of the addresses of the nodes in the network can be automatically done in order to avoid
this configuration. For that, basically, remove or comment all the variables related to the ip addresses (more information in [variables.tf](variables.tf)). With this approach all the addresses are retrieved based in the provided virtual network addresses range (`vnet_address_range`).

**Note:** If you are specifying the IP addresses manually, make sure these are valid IP addresses. They should not be currently in use by existing instances. In case of shared account usage, it is recommended to set unique addresses with each deployment to avoid using same addresses.

AWS has a pretty specific way of managing the addresses. Due to its architecture, each of the machines in a cluster must be in a different subnet to have HA capabilities. Besides that, the Virtual addresses must be outside of VPC address range too.

Example based on `10.0.0.0/16` address range (VPC address range) and `192.168.1.0/24` as `virtual_address_range` (the default value):

| Service                          | Variable                     | Addresses                                                      | Comments                                                                                            |
| ----                             | --------                     | ---------                                                      | --------                                                                                            |
| iSCSI server                     | `iscsi_srv_ip`               | `10.0.0.4`                                                     |                                                                                                     |
| Monitoring                       | `monitoring_srv_ip`          | `10.0.0.5`                                                     |                                                                                                     |
| HANA ips                         | `hana_ips`                   | `10.0.1.10`, `10.0.2.11`                                       |                                                                                                     |
| HANA cluster vip                 | `hana_cluster_vip`           | `192.168.1.10`                                                 | Only used if HA is enabled in HANA                                                                  |
| HANA cluster vip secondary       | `hana_cluster_vip_secondary` | `192.168.1.11`                                                 | Only used if the Active/Active setup is used                                                        |
| DRBD ips                         | `drbd_ips`                   | `10.0.5.20`, `10.0.6.21`                                       |                                                                                                     |
| DRBD cluster vip                 | `drbd_cluster_vip`           | `192.168.1.20`                                                 |                                                                                                     |
| S/4HANA or NetWeaver ips         | `netweaver_ips`              | `10.0.3.30`, `10.0.4.31`, `10.0.3.32`, `10.0.4.33`             | Addresses for the ASCS, ERS, PAS and AAS. The sequence will continue if there are more AAS machines |
| S/4HANA or NetWeaver virtual ips | `netweaver_virtual_ips`      | `192.168.1.30`, `192.168.1.31`, `192.168.1.32`, `192.168.1.33` | The last number of the address will match with the regular address                                  |

## Advanced Customization

### Terraform Parallelism

When deploying many scale-out nodes, e.g. 8 or 10, you should must pass the [`-nparallelism=n`🔗](https://www.terraform.io/docs/cli/commands/apply.html#parallelism-n) parameter to `terraform apply` operations.

It "limit[s] the number of concurrent operation as Terraform walks the graph."

The default value of `10` is not sufficient because not all HANA cluster nodes will get provisioned at the same. A value of e.g. `30` should not hurt for most use-cases.

### Remote State

**Important**: If you want to use remote terraform states, first follow the [procedure to create a remote terraform state](create_remote_state).

### AWS catalog images

The expected format of AWS catalog images, it could be the image name (for example, 'suse-sles-sap-15-sp4-byos' for BYOS image, 'suse-sles-sap-15-sp4-v20230630' for PAYG image) or image ID (for example, 'ami-0885658077f2f8415').
For example: Set os_image = 'suse-sles-sap-15-sp4-byos' or os_image = 'ami-0885658077f2f8415'.

You can query the images via [pint images🔗](https://pint.suse.com/?resource=images) or aws-cli command.
You can refer to [suse public cloud image life cycle🔗](https://www.suse.com/c/suse-public-cloud-image-life-cycle/) for the images states (active/inactive/deprecated).

### How to upload a custom image

This configuration uses the public **SUSE Linux Enterprise Server 15 for SAP Applications BYOS x86_64** image available in AWS (as defined in the file [variables.tf](variables.tf)) and can be used as is.

If the use of a private/custom image is required (for example, to perform the Build Validation of a new AWS Public Cloud image), first upload the image to the cloud using the [procedure described below](#upload-image-to-aws), and then [register it as an AMI](#import-ami-via-snapshot). Once the new AMI is available, edit its AMI id value in the [terraform.tfvars](terraform.tfvars.example) file for your region of choice.

To define the custom AMI in terraform, you should use the [terraform.tfvars](terraform.tfvars.example) file:

``` shell
hana_os_image = "ami-xxxxxxxxxxxxxxxxx"
```

You could also use an image available in the AWS store, in human readable form:

``` shell
hana_os_image = "suse-sles-sap-15-sp1-byos"
```

An image owner can also be specified:

``` shell
hana_os_owner = "amazon"
```

#### Upload image to AWS

Instead of the public OS images referenced in this configuration, the EC2 instances can also be launched using a private OS images as long as it is uploaded to AWS as a Amazon Machine Image (AMI). These images have to be in raw format.

In order to upload the raw images as an AMI, first an Amazon S3 bucket is required to store the raw image. This can be created with the following command using the aws-cli (remember to configure aws-cli access with `aws configure`):

``` shell
aws s3 mb s3://instmasters --region eu-central-1
```

This creates an S3 bucket called `instmasters`, which will be used during the rest of this document. Verify the existing S3 buckets in the account with `aws s3 ls`.

After the bucket has been created, the next step is to copy the raw image file to the bucket; be sure to decompress it before uploading it to the S3 bucket:

``` shell
unxz SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw.xz
aws s3 cp SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw s3://instmasters/
```

The above example is using the SLES 12-SP4 for SAP for EC2 BYOS raw image file. Substitute that with the file name of the image you wish to test.

##### Create AMI

###### IAM Role creation and setup

Once the raw image file is in an Amazon S3 bucket, the next step is to create an IAM role and policy to allow the import of images.

First, create a `trust-policy.json` file with the following content:

``` json
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": { "Service": "vmie.amazonaws.com" },
         "Action": "sts:AssumeRole",
         "Condition": {
            "StringEquals":{
               "sts:Externalid": "vmimport"
            }
         }
      }
   ]
}
```

Then, create a `role-policy.json` file with the following content:

``` json
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Action":[
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
         ],
         "Resource":[
            "arn:aws:s3:::instmasters",
            "arn:aws:s3:::instmasters/*"
         ]
      },
      {
         "Effect":"Allow",
         "Action":[
            "ec2:ModifySnapshotAttribute",
            "ec2:CopySnapshot",
            "ec2:RegisterImage",
            "ec2:Describe*"
         ],
         "Resource":"*"
      }
   ]
}
```

Note that the `role-policy.json` file references the `instmasters` S3 Bucket, so change that value accordingly.

Once the files have been created, run the following commands to create the `vmimport` role and to put the role policy into it:

``` shell
aws iam create-role --role-name vmimport --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://role-policy.json
```

Check the output of the commands for any errors.

##### Import AMI

To import the raw image into an AMI, the command `aws ec2 import-image` needs to be called.
This command requires a disk containers file which specifies the location of the raw image file
in the S3 Bucket, as well as the description of the AMI to import.

First create a `container.json` file with the following content:

``` json
[
  {
     "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
     "Format": "raw",
     "UserBucket": {
         "S3Bucket": "instmasters",
         "S3Key": "SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw"
     }
  }
]
```

Substitute the values for `Description`, `S3Bucket` and `S3Key` with the values corresponding to the image you wish to upload and the S3 Bucket where the raw file is located.

Once the file is created, import the image with the command:

``` shell
aws ec2 import-image --description "SLES4SAP 12-SP4 Beta4 Build 1.1" --license BYOL --disk-containers file://container.json
```

Again, substitute the description with the description text of the image you will be testing.

The output of the `aws ec2 import-image` should look like this:

``` json
{
    "Status": "active",
    "LicenseType": "BYOL",
    "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
    "Progress": "2",
    "SnapshotDetails": [
        {
            "UserBucket": {
                "S3Bucket": "instmasters",
                "S3Key": "SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw"
            },
            "DiskImageSize": 0.0,
            "Format": "RAW"
        }
    ],
    "StatusMessage": "pending",
    "ImportTaskId": "import-ami-0e6e37788ae2a340b"
}
```

This will say that the import process is active and that it is pending, so you will need the `aws ec2 describe-import-image-tasks` command to check the progress. For example:

``` shell
aws ec2 describe-import-image-tasks --import-task-ids import-ami-0e6e37788ae2a340b

{
    "ImportImageTasks": [
        {
            "Status": "active",
            "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
            "Progress": "28",
            "SnapshotDetails": [
                {
                    "Status": "active",
                    "UserBucket": {
                        "S3Bucket": "instmasters",
                        "S3Key": "SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw"
                    },
                    "DiskImageSize": 10737418240.0,
                    "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
                    "Format": "RAW"
                }
            ],
            "StatusMessage": "converting",
            "ImportTaskId": "import-ami-0e6e37788ae2a340b"
        }
    ]
}
```

Wait until the status is **completed** and search for the image id to use in the test. This image id (a string starting with `ami-`) should be added to the file [variables.tf](variables.tf) in order to be used in the terraform configuration included here.

##### Import AMI via snapshot

An alternate way to convert a raw image into an AMI is to first upload a snapshot of the raw image, and then convert the snapshot into an AMI. This is helpful sometimes as it bypasses some checks performed by `aws ec2 import-image` such as kernel version checks.

First, create a `container-snapshot.json` file with the following content:

``` json
{
     "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
     "Format": "raw",
     "UserBucket": {
         "S3Bucket": "instmasters",
         "S3Key": "SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw"
     }
}
```

Notice that the syntax of the `container.json` file and the `container-snapshot.json` file
are mostly the same, with the exception of the opening and closing brackets on the `container.json` file.

Substitute the Description, S3Bucket and S3Key for the correct values of the image to validate.
In the case of the `instmasters` bucket, the S3Key can be found with `aws s3 ls s3://instmasters`.

Once the file has been created, import the snapshot with the following command:

``` shell
aws ec2 import-snapshot --description "SLES4SAP 12-SP4 Beta4 Build 1.1" --disk-container file://container-snapshot.json
```

The output of this command should look like this:

``` json
{
    "SnapshotTaskDetail": {
        "Status": "active",
        "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
        "Format": "RAW",
        "DiskImageSize": 0.0,
        "Progress": "3",
        "UserBucket": {
            "S3Bucket": "instmasters",
            "S3Key": "SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw"
        },
        "StatusMessage": "pending"
    },
    "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
    "ImportTaskId": "import-snap-0fbbe899f2fd4bbdc"
}
```

Similar to the `import-image` command, the process stays running in the background in AWS.
You can check its progress with the command:

``` shell
aws ec2 describe-import-snapshot-tasks --import-task-ids import-snap-0fbbe899f2fd4bbdc
```

Be sure to use the proper `ImportTaskId` value from the output of your `aws ec2 import-snapshot` command.

When the process is completed, the `describe-import-snapshot-tasks` command will output something like this:

``` json
{
    "ImportSnapshotTasks": [
        {
            "SnapshotTaskDetail": {
                "Status": "completed",
                "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
                "Format": "RAW",
                "DiskImageSize": 10737418240.0,
                "SnapshotId": "snap-0a369f803b17037bb",
                "UserBucket": {
                    "S3Bucket": "instmasters",
                    "S3Key": "SLES12-SP4-SAP-EC2-HVM-BYOS.x86_64-0.9.2-Build1.1.raw"
                }
            },
            "Description": "SLES4SAP 12-SP4 Beta4 Build 1.1",
            "ImportTaskId": "import-snap-0fbbe899f2fd4bbdc"
        }
    ]
}
```

Notice the **completed** status in the above JSON output.

Also notice tne `SnapshotId` which will be used in the next step to register the AMI.

Once the snapshot is completely imported, the next step is to register an AMI with the command:

``` shell
aws ec2 register-image --architecture x86_64 --description "SLES 12-SP4 Beta4 Build 1.1" --name sles-12-sp4-b4-b1.1 --root-device-name "/dev/sda1" --virtualization-type hvm --block-device-mappings "DeviceName=/dev/sda1,Ebs={DeleteOnTermination=true,SnapshotId=snap-0a369f803b17037bb,VolumeSize=40,VolumeType=gp2}"
```

Substitute in the above command line the description, name and snapshot id with the appropriate values for your image.

The output, should include the image id. This image id (a string starting with `ami-`) should be added to the file [variables.tf](variables.tf) in order to be used in the terraform configuration included here.

More information regarding the import of images into AWS can be found in [this Amazon document🔗](https://docs.aws.amazon.com/vm-import/latest/userguide/vmimport-image-import.html) or in [this blog post🔗](https://www.wavether.com/2016/11/import-qcow2-images-into-aws).

Examples of the JSON files used in this document have been added to this repo.

## Troubleshooting

In case you have some issue, take a look at this [troubleshooting guide](../doc/troubleshooting.md).
