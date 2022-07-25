# syntax=docker/dockerfile:experimental

FROM opensuse/tumbleweed:latest
RUN zypper ref && zypper up -y
#RUN zypper in -y azure-cli

# way suggested on https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=zypper
RUN zypper install -y tar gzip unzip curl python310-pip
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc
RUN zypper addrepo --name 'Azure CLI' --check https://packages.microsoft.com/yumrepos/azure-cli azure-cli
RUN zypper install --from azure-cli -y azure-cli
RUN zypper clean --all


WORKDIR /root
RUN curl https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-387.0.0-linux-x86_64.tar.gz -o google-cloud-cli.tar.gz
RUN tar xvf google-cloud-cli.tar.gz
RUN google-cloud-sdk/install.sh --quiet --usage-reporting false --command-completion true
RUN echo 'source /root/google-cloud-sdk/completion.bash.inc' >> ~/.bashrc
RUN echo 'source ~/google-cloud-sdk/path.bash.inc' >> ~/.bashrc
RUN rm google-cloud-cli.tar.gz

RUN curl https://releases.hashicorp.com/terraform/1.1.7/terraform_1.1.7_linux_amd64.zip -o terraform.zip
RUN unzip terraform.zip -d /usr/local/bin
RUN terraform -install-autocomplete
RUN rm terraform.zip

COPY requirements.txt .
RUN pip install -r requirements.txt

RUN mkdir /src
WORKDIR /src
