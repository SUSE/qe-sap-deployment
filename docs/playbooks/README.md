# Ansible Playbooks

The playbooks in this project are written to be executed after
`terraform apply` and in the following order:

* registration.yaml
* ibsm.yaml (optional)
* pre-cluster.yaml
* sap-hana-preconfigure.yaml
* cluster_sbd_prep.yaml
* sap-hana-storage.yaml
* sap-hana-download-media.yaml
* sap-hana-install.yaml
* sap-hana-system-replication.yaml
* sap-hana-system-replication-hooks.yaml
* sap-hana-cluster.yaml

This README describes what each playbook seek to achieve and the inputs
required.

## Idempotency

Ideally all playbooks in this project should be written to be idempotent,
but not all of them are: sap-hana-install is not idempotent yet.
The playbooks are intended to be run on freshly created systems
which have not been manually managed.
If run against manually configured systems, then some plays may not act as expected.

## registration

Target hosts:

* all

Variables:

* use_suseconnect
* reg_code
* email_address
* sles_modules

Variable Source = from the command line in the conf.yaml

The 'registration' playbook registers the SLES for SAP installations with SCC.
The playbook will check for the existence of repositories available to zypper.
If repos are found, the playbook assumes registration is not required and
quits.

If no repos are found, the playbook will first attempt to register with SCC
using `registercloudguest`. If the command is available, it will be used for
registration. If `registercloudguest` is not available then `SUSEConnect` will
be used.


There's a task allowing register additional modules that require a dedicated regcode.
The module names and regcodes can be provided in the `ansible-playbook` command line as list of hashes (named sles_modules).

The format should be like this:

```
create:
    - registration.yaml (.......other variables here......) -e sles_modules='[{"key":"<module1>","value":"<regcode1>"},{"key":"<module2","value":"<regcode2>"}]'
```

## ibsm

Target hosts:

* all

Variables:

* ibsm_ip
* download_hostname
* repos
* priority

Variable Source = from the command line in the conf.yaml

This optional playbook points the hosts at an IBS mirror: it adds the mirror
to `/etc/hosts` and registers the comma separated list of `repos` as zypper
repositories aliased `TEST_<index>`, then refreshes all the repositories.

It is used to test packages that are not in SCC yet. Because it changes where
zypper takes the packages from, it has to run **before**
`pre-cluster.yaml` and after `registration.yaml`.

Note that adding the mirror does not by itself guarantee that a package comes
from it: zypper still resolves by version and repository priority. Use the
`priority` variable when the mirror has to win over the SCC repositories.

## pre-cluster

Target hosts:

* hana and iscsi (repository guard and the package plays)
* all (the /etc/hosts and ssh key preparation)

Variables:

* use_sapconf
* use_sbd
* use_sap_hana_sr_angi
* use_ibsm
* cluster_node - defaults to true; false skips every cluster package
* scale_out - defaults to false

Variable Sources:

* `./vars/hana_vars.yaml`, which is optional here: it only exists when the
  conf.yaml has an `ansible::hana_vars` section, and the playbook falls back
  on its own defaults without it
* the terraform inventory, which provides `use_sbd`; `cloud_platform_name` is
  set there for some providers and otherwise derived by
  `./tasks/detect-cloud-platform.yaml`
* the command line in the conf.yaml, for `use_sapconf` and `use_ibsm`.
  `use_ibsm` has to come from the command line: the guard runs in the first
  play, which does not read `hana_vars.yaml`.

This playbook does two things. It is **the single place where the deployment
installs packages**, and it performs the preparation the cluster needs.

All the `zypper` package installations that used to be spread over
`sap-hana-preconfigure.yaml`, `cluster_sbd_prep.yaml` and
`sap-hana-cluster.yaml` (and their task files) have been collected here, so
that there is exactly one point in the deployment where packages are pulled
from the repositories. Those playbooks now only configure the corresponding
services, and most of them assert that this one has already run. The
exception is `tasks/azure-cluster-bootstrap.yaml`, which has no such assert:
on Azure a missing cluster package surfaces later as a crm or fencing error
rather than a clear message.

The playbook is four plays, in this order:

1. **Assert the repositories are ready** (`hana:iscsi`) - the repository
   guard. Only the hosts that go on to install packages need it. It
   sets `any_errors_fatal`, so a single host failing it aborts the whole run.
   Without that only the failing host would be dropped and the survivors
   would be packaged and configured on their own, leaving a half built
   cluster behind.
2. **Install packages on the HANA nodes** (`hana`).
3. **Install packages on the iSCSI server** (`iscsi`).
4. **Cluster preparation** (`all`) - `/etc/hosts` entries, ssh key pairs and
   known_hosts, as before.

**Package installation needs the repositories in their final state**, which
means this playbook must run after `registration.yaml` and, when an IBS
mirror is used, after `ibsm.yaml`. Both are already true of the documented
sequence; the first play verifies it rather than assuming it, checking that:

* `zypper lr` does not exit 6, its "no repository is defined" code - any
  other zypper failure is not treated as a registration problem - and
  `SUSEConnect --status` does
  not report any base product as `Not Registered`. Only the base products are
  checked, because a deployment can legitimately leave some optional module
  not activated.
* at least one enabled `TEST_<index>` repository, the alias used by
  `ibsm.yaml`, is configured. This one is only enforced when `use_ibsm` is
  true, since most deployments do not use a mirror. Note that the check proves
  the mirror is configured, not that a given package is resolved from it: see
  the `ibsm` section about repository priority.

If either check fails the playbook stops immediately with an explicit message
instead of letting every single package task fail.

The `hana` play installs, depending on the variables and on the detected cloud
platform and OS version:

* the HANA prerequisites (GCC 10 libraries, `libssh2-1` for scale out,
  `ClusterTools2`, `iscsiuio`/`open-iscsi` when SBD is used, `lsscsi` on
  SLES 16)
* either `SAPHanaSR`/`SAPHanaSR-doc` or `SAPHanaSR-angi` plus
  `supportutils-plugin-ha-sap`, according to `use_sap_hana_sr_angi`
* the tuning daemon: `sapconf` when `use_sapconf` is true (removing the
  conflicting `tuned` on SLE 12), otherwise `saptune` and, on SLES 16 with
  saptune >= 3.2.3, `patterns-cockpit`. All three are installed **only if a
  `zypper search` finds them**; when neither exists the install is skipped and
  `sap-hana-preconfigure.yaml` skips the tuning too, so the deployment succeeds
  with an untuned node rather than failing. The probe distinguishes a genuinely
  absent package from a broken zypper - an unreachable repository also exits
  104 - by checking stdout and stderr for a repository error, and fails loudly
  on that rather than skipping. It runs with `LC_ALL=C` so the check does not
  depend on the target's language
* the cluster packages, when `cluster_node` is true: `socat`,
  `resource-agents`, `fence-agents-azure-arm` and the Azure Python SDK modules
  on Azure; the full corosync/pacemaker/crmsh package set on AWS and GCP

The `iscsi` play installs `targetcli-fb` on SLE 12 and `python3-targetcli-fb`
on SLE 15 and 16, removing first the packages that conflict with it on
12-SP5.

Three package operations are intentionally **not** part of this playbook:

* `registration.yaml` updates `cloud-regionsrv-client` as part of the
  registration itself, so it has to stay there
* `ptf_installation.yaml` installs local RPM files that it downloads itself,
  so it does not depend on the repositories. It is not part of the standard
  sequence, but when it is used it has to run **after** `pre-cluster.yaml`:
  the other way round the repository versions installed here can replace the
  PTFs, silently.
* `fully-patch-system.yaml` runs `zypper patch` over everything. It is also
  not part of the standard sequence, and for the same reason it should run
  after `pre-cluster.yaml`.

**`use_sapconf` has to agree with `sap-hana-preconfigure.yaml`.** This
playbook decides which tuning daemon to *install*, that one configures it, and
the two read the variable independently. Pass the same value on both lines of
the conf.yaml. A mismatch usually fails in `sap-hana-preconfigure.yaml` with an
explicit message naming this playbook - but not always: if the daemon that
playbook wants is not available on the host at all, the tuning is skipped
instead and the node ends up with neither daemon configured, with the run
still green. Nothing detects that case.

## sap-hana-preconfigure

Target hosts:

* hana

Variables:

* use_sapconf
* firewall_cfg

Variable Source = ./vars/hana_vars.yaml that can be populated by ansible::hana_vars in the conf.yaml

`use_sap_hana_sr_angi` is no longer read here: the SAPHanaSR package choice it
drives moved to `pre-cluster.yaml`.

The 'sap-hana-preconfigure' playbook is used to tune the HANA nodes for
SAP HANA. The additionally required packages are installed by
`pre-cluster.yaml`; this playbook only tunes the OS for HANA.
If the variable `use_sapconf` is true, then
sapconf will be used to tune the installation. If `use_sapconf` is not set or
is set to false, the system is tuned by `saptune` instead. Note that this
variable must match the one given to `pre-cluster.yaml`, which installs the
daemon this playbook then configures.

The `firewall_cfg` variable is used as a centralized source of truth for firewall
management across all playbooks. Possible values are:
* `enable`: The firewalld service is started/enabled and required ports (HANA, iSCSI, cluster) are opened.
* `disable`: The firewalld service is stopped/disabled.
* `ignore` (Default): The firewall configuration is not touched by Ansible.

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

The variables for this playbook that start with `config_` are optional. They
are mostly the names of the iscsi devices that will be created. If the
variables are empty, defaults will be used. The exception is sap_storage_dict.
This variable must be set, however, the default values in
./ansible/playbooks/vars/iscsi-storage-profile.yaml will be suitable unless
significant changes have been made to the iscsi Terraform configuration.

The iscsi server packages, and the removal of the packages known to conflict
with them, are handled by `pre-cluster.yaml`. The iscsi server tasks
ensure that the iscsi services are enabled and running. The playbook then creates an
LVG, LV and file system which is to be used to store the iscsi LUN. The file
system is mounted and added to `/etc/fstab`. Finally, the iscsi LUN is
created and ACLs are added to allow the clients to access the LUN.

The iscsi client tasks first ensure that the client iscsi initiators match the
created ACL on the server. If changes are made to the initiator files, the
iscsi service will be restarted. Following this, the clients will scan the
server for and attempt to login. The discovered system will be configured
so that the discovered disks will be automatically logged into every time the
system boots.

The sbd client task file is will search for ALL discovered iscsi disks and
attempt to add these to the SBD configuration. Before creating SBD devices,
the code will attempt to dump the SBD info from the discovered disks. If
this fails, the code assumes that it is safe to use the disk. If an SBD
header exists on the disk, a new one will not be attempted. Finally,
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
file systems required by SAP HANA. This playbook consumes the `sap_storage`
role. This role has temporarily been copied into this project. In a future
release this will be removed and pulled at runtime using `ansible-galaxy`.

This playbook requires the variable sap_storage_dict. A standard variable
is automatically sourced from
`./ansible/playbooks/vars/hana_storage_profile.yaml`. This only needs to
be altered if the default terraform is not used.

## sap-hana-download-media

Target hosts:

* hana

Variables:

* hana_urls

Variable Sources:

* ./ansible/playbooks/vars/hana_storage_profile.yaml

In order to install HANA, the media must be presented. This playbook downloads
from a url. It is this users responsibility to provide urls for the following:

* SAPCAR for x86_64 Linux - this must be named SAPCAR.EXE!
* SAP HANA Server 2.0 SAR file

Other SAR files may also be added and these will automatically be installed.

The URLS must be placed into a list named `hana_urls` in
`./ansible/playbooks/vars/hana_storage_profile.yaml`. The file should be
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

sap_hana_install_software_directory
sap_hana_install_master_password:
sap_hana_install_sid:
sap_hana_install_instance_number:
sap_domain:
primary_site:
secondary_site:

Variable Sources:

* ./ansible/playbooks/vars/hana_vars.yaml

The sap-hana-install playbook, like the sap-hana-storage playbook, uses an
external role. The playbook consumes the role to install HANA on both
HANA nodes. The minimal configuration example is pre-populated in the supplied
vars file `./ansible/playbooks/vars/hana_vars_example.yaml`. This file can be
used as a template for `./ansible/playbooks/vars/hana_vars.yaml`, which must be
present! The vars is sourced by various playbooks and contains more fields
than are strictly necessary for just installing HANA. However, this vars file
is sourced by multiple playbooks and enables system replication and clustering.
By having the HANA vars in a single file, consistency is assured across the
playbooks that rely on HANA related variables.

## sap-hana-system-replication

Target hosts:

* hana

Mandatory variables:

sap_hana_install_software_directory
sap_hana_install_master_password:
sap_hana_install_sid:
sap_hana_install_instance_number:
sap_domain:
primary_site:
secondary_site:

Variable Sources:

* ./ansible/playbooks/vars/hana_vars.yaml

The sap-hana-system-replication playbook configures SAP system replication
across two HANA nodes.  Like the sap-hana-install playbook, it requires
the `./ansible/playbooks/vars/hana_vars.yaml` vars file.  The playbook
will ensure backups exists of all primary databases and then configure
HANA System Replication. Again, this playbook uses an external role
provided by the SAP Linux Lab.

## sap-hana-system-replication-hooks

Target hosts:

* hana

Mandatory variables:

sap_hana_install_software_directory
sap_hana_install_master_password:
sap_hana_install_sid:
sap_hana_install_instance_number:
sap_domain:
primary_site:
secondary_site:

Variable Sources:

* ./ansible/playbooks/vars/hana_vars.yaml

Following the system replication playbook, it is necessary to install and
configure the system replication hooks. This playbook performs the steps
required to ensure the hooks are installed and that `sudo` is correctly
configured.  Like the previous two playbooks, this one also uses the
`hana_vars.yaml` vars file for consistency.

## sap-hana-cluster

Target hosts:

* hana

Mandatory variables:

sap_hana_install_software_directory
sap_hana_install_master_password:
sap_hana_install_sid:
sap_hana_install_instance_number:
sap_domain:
primary_site:
secondary_site:

Variable Sources:

* ./ansible/playbooks/vars/hana_vars.yaml

The sap-hana-cluster playbook is a complicated one.
The playbook can currently create clusters using either of
two fencing types: SBD or native fencing. The table
below shows what is currently supported and which STONITH
agent is used for native fencing on each cloud.

| Type  | SBD Fencing | Native Fencing | Native STONITH agent                |
|-------|-------------|----------------|-------------------------------------|
| AWS   | Yes         | Yes            | `stonith:external/ec2`              |
| Azure | Yes         | Yes            | `stonith:fence_azure_arm` (MSI/SPN) |
| GCP   | Yes         | Yes            | `stonith:fence_gce`                 |

Like the other playbooks that are directly connected to HANA operations,
this playbook also sources `hana_vars.yaml` for consistency. By default,
an SBD based cluster will not be created.

### AWS native fencing

AWS uses the `stonith:external/ec2` agent. Following the SUSE/AWS
reference architecture for SAP HANA HA on SLES, the playbook sets the
cluster property `stonith-action=off`, which forces the EC2 STONITH
agent to **stop** the fenced instance via the EC2 API rather than
reboot it. This prevents a fenced node from automatically rejoining
the cluster — which on AWS could otherwise lead to split brain — and
forces an operator to deliberately reintroduce the node. See the
[AWS guide](https://docs.aws.amazon.com/sap/latest/sap-hana/sap-hana-on-aws-stonith-device.html)
for details. The corresponding `stonith-timeout` is `600s`.

### GCP native fencing

GCP uses the `stonith:fence_gce` agent. Per Google's
[SAP HANA HA SLES guide](https://cloud.google.com/solutions/sap/docs/sap-hana-ha-config-sles#create_the_fencing_device_resources),
fencing is configured with one `fence_gce` primitive per node and a
`LOC_STONITH_<hostname>` location constraint that pins each agent
away from the node it would fence (preventing self-fencing). The
cluster property `stonith-action` is left at Pacemaker's default
(`reboot`); the fenced GCE instance is rebooted via the GCP API and
rejoins the cluster automatically. The corresponding `stonith-timeout`
is `300s`.

### Azure native fencing

To use Azure native fencing you must:

* Be using the azure provider in terraform
* **Provide the following variables:**
  * identity_management - 'msi' or 'spn'
  * spn_application_id - SPN fencing app id
  * spn_application_password - Password used for SPN based fencing
* **Variables below are provided by terraform output:**
  * subscription_id
  * resource_group
  * tenant_id

The five additional variables all relate to the SAP fencing application
that needs to be created. At this point, the creation of the fencing
application is not automated. Follow [these instructions](https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/sap/high-availability-guide-suse-pacemaker#create-azure-fence-agent-stonith-device)
to create the fencing application.
