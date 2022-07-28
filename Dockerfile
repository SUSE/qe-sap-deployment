# syntax=docker/dockerfile:experimental

FROM opensuse/tumbleweed:latest
RUN zypper ref && zypper up -y

## AZURE
# way suggested on https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=zypper
RUN zypper install -y tar gzip unzip curl python310-pip openssh && \
    rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    zypper addrepo --name 'Azure CLI' --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli && \
    zypper install --from azure-cli -y azure-cli && \
    zypper clean --all

WORKDIR /root

## GCP
RUN curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-387.0.0-linux-x86_64.tar.gz -o google-cloud-cli.tar.gz && \
    tar xvf google-cloud-cli.tar.gz && \
    google-cloud-sdk/install.sh --quiet --usage-reporting false --command-completion true && \
    echo 'source /root/google-cloud-sdk/completion.bash.inc' >> ~/.bashrc && \
    echo 'source ~/google-cloud-sdk/path.bash.inc' >> ~/.bashrc && \
    rm google-cloud-cli.tar.gz

## Terraform
RUN curl https://releases.hashicorp.com/terraform/1.1.7/terraform_1.1.7_linux_amd64.zip -o terraform.zip && \
    unzip terraform.zip -d /usr/local/bin && \
    terraform -install-autocomplete && \
    rm terraform.zip

COPY requirements.txt .
RUN pip install -r requirements.txt

RUN mkdir /src
WORKDIR /src
