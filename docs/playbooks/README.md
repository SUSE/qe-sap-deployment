# Ansible Playbooks

The playbooks in this project are written to be executed after
`terrform apply`  and in the following order:

* registration.yaml
* sap-hana-preconfigure.yaml
* cluster_sbd_prep.yaml
* sap-hana-storage.yaml
* sap-hana-download-media.yaml
* sap-hana-install.yaml

This README describes what each playbook seek to achieve and the inputs
required.

## Idempotency

All playbooks are written to be idempotent.  The playbooks are intended to be
run on freshly created systems which have not been manually managed.  If run
against manually configured systems the some plays may not act as expected.  

## registration

Target hosts:

* all

Variables:

* reg_code
* email_address

Variable Source = ./variables.sh

The 'registration' playbook registers the SLES for SAP installations with SCC.
The playbook will check for the existence of repositories available to zypper.
If repos are found, the playbook assumes registration is not required and
quits.

If no repos are found, the playbook will first attempt to register with SCC
using `registercloudguest`.  If the command is available, it will be used for
registration.  If `registercloudguest` is not available then `SUSEConnect` will
be used.

## sap-hana-preconfigure

Target hosts:

* hana

Variables:

* use_sapconf

Variable Source = ./variables.sh

The 'sap-hana-preconfigure' playbook is used to tune the HANA nodes for
SAP HANA.  It will install any additionally required packages and then
attempt to tune the OS for HANA.  If the variable `use_sapconf` is true, then
sapconf will be used to tune the installation.  If `use_sapconf is not set or
is set to false, not tuning will take place.  In the future the system will
be tuned by saptune by default.

## cluster_sbd_prep

Target hosts:

* hana
* iscsi

Variables:

* config_backstore_name
* config_server_iqn_name_authority
* config_server_meaningful_name
* config_client01_iqn_name_authority
* config_client02_iqn_name_authority
* config_client01_meaningful_name
* config_client02_meaningful_name
* sap_storage_dict

Variable Sources:

* ./ansible/playbooks/vars/sbd-parameters
* ./ansible/playbooks/vars/iscsi-storage-profile.yaml

The cluster_sbd_prep playbook sources three task files which performs
the following tasks:

* Configures iscsi server and exports LUNs to the HANA nodes
* Configures iscsi clients and logins in to the iscsi targets
* Discovers the iscsi disks, creates SBD devices and configures the
configuration file

All of the task files are designed to independent from each other and can be
run in isolation using tags.

The variables for this playbook that start with `config_` are optional.  They
are mostly the names of the iscsi devices that will be created.  If the
variables are empty, defaults will be used.  The exception is sap_storage_dict.
This variable must be set, however, the default values in
./ansible/playbooks/vars/iscsi-storage-profile.yaml will be suitable unless
significant changes have been made to the iscsi Terraform configuration.

The iscsi server tasks will ensure that the correct packages are installed and
remove any packages that are known to conflict with these.  It then ensures
that the iscsi services is enabled and running.  The playbook then creates am
LVG, LV and file system which is to be used to store the iscsi LUN.  The file
system is mounted and added to `/etc/fstab`.  Finally, the iscsi LUN is
created and ACLs are added to allow the clients to access the LUN.

The iscsi client tasks first ensure that the client iscsi initiators match the
created ACL on the server.  If changes are made to the initiator files, the
iscsi service will be restarted.  Following this, the clients will scan the
server for and attempt to login.  The discovered system will be configured
so that the discovered disks will be automatically logged into every time the
system boots.

The sbd client task file is will search for ALL discovered iscsi disks and
attempt to add these to the SBD configuration.  Before creating SBD devices,
the code will attempt to dump the SBD info from the discovered disks.  If
this fails, the code assumes that it is safe to use the disk.  If an SBD
header exists on the disk, a new one will not be attempted.  Finally,
all discovered iscsi disks will be added to the configuration file
(/etc/sysconfig/sbd) along with the other required settings.

## sap-hana-storage

Target hosts:

* hana

Variables:

* sap_storage_dict

Variable Sources:

* ./ansible/playbooks/vars/hana_storage_profile.yaml

The sap-hana-storage playbook is responsible for creating the LVGs, LVs and
file systems required by SAP HANA.  This playbook consumes the `sap_storage`
role.  This role has temporarily been copied into this project.  In a future
release this will be removed and pulled at runtime using `ansible-galaxy`.

This playbook requires the variable sap_storage_dict.  A standard variable
is automatically sourced from
`./ansible/playbooks/vars/hana_storage_profile.yaml`.  This only needs to
be altered if the default terraform is not used.

## sap-hana-download-media

Target hosts:

* hana

Variables:

* hana_urls

Variable Sources:

* ./ansible/playbooks/vars/hana_storage_profile.yaml

In order to install HANA, the media must be presented.  This playbook downloads
from a url.  It is this users responsibility to provide urls for the following:

* SAPCAR for x86_64 Linux - this must be named SAPCAR.EXE!
* SAP HANA Server 2.0 SAR file

Other SAR files may also be added and these will automatically be installed.

The URLS must be placed into a list named `hana_urls` in
`./ansible/playbooks/vars/hana_storage_profile.yaml`.  The file should be
similar to this example:

```yaml
hana_urls:
  - https://myazurestorageaccount.blob.core.windows.net/sapblobs/SAPCAR.EXE
  - https://myazurestorageaccount.blob.core.windows.net/sapblobs/IMDB_SERVER20_062_0-80002031.SAR
  - https://myazurestorageaccount.blob.core.windows.net/sapblobs/IMDB_CLIENT20_012_25-80002082.SAR
```

The playbook simply downloads all of the urls to /hana/shared/install where
they are later consumed by the install.

## sap-hana-install

Target hosts:

* hana

Mandatory variables:

sap_hana_install_software_directory:
sap_hana_install_master_password:
sap_hana_install_sid:
sap_hana_install_instance_number:

Variable Sources:

* ./ansible/playbooks/vars/sap-hana-install_vars.yaml

The sap-hana-install playbook, like the sap-hana-storage playbook, uses an
external role.  The playbook consumes the role to install HANA on both
HANA nodes.  The minimal configuration is pre-populated in the supplied
vars file `./ansible/playbooks/vars/sap-hana-install_vars.yaml`.  It should
not be necessary to alter the file unless there is a special need, such as
testing specific SID names, instance numbers, installing in non-default
locations etc.
