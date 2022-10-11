# Creating and configuring a secure storage account for SAP Media

This project require access to SAP media to install and configure SAP software.
Therefore, SAP media must be made available to the project.  However, SAP
software is not propriety, licenced and not available for public download.
Therefore care must be taken to ensure that the media is handled correctly
and is not inadvertently leaked.

At the same time, a the media must not be too complicated for the project
to handle thus making the code to manage the software fragile and unwieldy.

To decrease complexity, media for this project will always be uploaded to
a blob container in an Azure Storage Account.  The contents will be
secured with a SAS token.

## Creating an Azure Storage Account

An Azure Storage Account can be created using `az` cli tool.  First off, a
resource group is required for the storage account to be associated with.
For example, to create a resource group named `sapmedia-rg` in the `uk_south`
azure region, the command would be:

```shell
az group create --name sapmedia-rg -l uksouth
```

Once a resource group is identified or created, the storage account can also
be created.  Storage account names must be between 3 and 24 characters in
length and may contain numbers and lowercase letters only. Storage account
names must be unique within Azure.  For example, to create a storage account
named in the `qesapmedia` in the `uk_south` region using the previously
created resource group, the command would be:

```shell
az storage account create --name qesapmedia --resource-group sstringer-delme-rg --location uksouth
```

Of course, there are numerous options for creating storage accounts, but only
the basics are required for our example.

The SAP media will be stored as blobs.  Blobs are stored in containers and
therefore a container will need to be created.  To create a blob container
named `sapmedia` in the newly created storage account, run the following
command:

```shell
az storage container create -n sapmedia --account-name qesapmedia
```

## Allowing secure access the SAS tokens

If the storage account and container were created using the above
instructions then the blobs stored within will not be available to the
public.  To allow secure, private access to blobs a SAS token needs to
be generated.  A SAS tokens are have start and expiration dates, allowing
tokens to expire over time.  To create a SAS token which allows read only
access and expires on 1/1/2025 for the container created with the above
instructions, run the following:

```shell
az storage container generate-sas --account-name qesapmedia --expiry 2025-01-01 --name sapmedia --permissions r
```

A string will be returned in the form of a string.  Copy this string a store it
securely.  This string will not be recoverable from Azure!

`se=2025-01-01&sp=r&sv=2021-06-08&sr=c&sig=eVeeKemQgXN5e2ilTgpOq89xmuiOCPkbkFbCH2rJOS0%3D`

## Uploading blobs

Blobs can be uploaded using `az` cli tool or in the portal. To upload a file
named `sapcar.exe` to a blob to the container created in the above commands
using the cli, see the following
command:

```shell
az storage blob upload -fsapcar.exe --account-name qesapmedia -c sapmedia -n sapcar.exe
```

The url of this blob will be
"https://qesapmedia.blob.core.windows.net/sapmedia/sapcar.exe".  This is
composed of the storage account name, container name and blob name.
The template is:

```shell
https://<storage_account_name>.blob.core.windows.net/<container_name>/<blob_name>
```

This url cannot be downloaded by the public, even if the URL is leaked.
However, appending the SAS key to the URL will allow it to be securely
downloaded.  As long as the URL and SAS token are stored securely, there is
no public access to the data.

### How to consume with Ansible

The old playbook used to take a single variable which was a list of blob urls.
The new version of the playbook will take four variables:

* az_storage_account_name: string
* az_container_name:       string
* az_blobs:                list of strings
* az_sas_token:            string

All of the blobs will need to be in the same container for the download to work
correctly.

The playbook will compile the complete urls and download the media to `hana_download_path`
which by default is `/hana/shared/install`.
