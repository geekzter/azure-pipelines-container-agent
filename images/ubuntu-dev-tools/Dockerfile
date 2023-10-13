FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y -qq --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    git \
    iputils-ping \
    jq \
    lsb-release \
    software-properties-common \
    tmux \
    wget

# Google repo
RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
    tee /etc/apt/sources.list.d/kubernetes.list

# Helm repo
RUN curl https://baltocdn.com/helm/signing.asc | \
    gpg --dearmor | \
    tee /usr/share/keyrings/helm.gpg > /dev/null
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
    tee /etc/apt/sources.list.d/helm-stable-debian.list

# Hashicorp repo
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

# Microsoft repos
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
RUN dpkg -i packages-microsoft-prod.deb
RUN echo "deb [arch=`dpkg --print-architecture`] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/azure-cli.list

RUN apt-get update

# Hashicorp packages
RUN apt-get install -y terraform

# Microsoft packages
RUN apt-get install -y azure-cli 

# PowerShell, do not rely on apt as no arm64 package is available
ARG PS_VERSION=7.3.8
ARG PS_PACKAGE=powershell-${PS_VERSION}-linux-arm64.tar.gz
# ARG PS_PACKAGE=powershell-${PS_VERSION}-linux-${TARGETARCH}.tar.gz
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}
RUN echo $PS_PACKAGE_URL
# RUN curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.3.8/powershell-7.3.8-linux-arm64.tar.gz
RUN curl -L -o /tmp/powershell.tar.gz $PS_PACKAGE_URL
RUN mkdir -p /opt/microsoft/powershell/7
RUN tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
RUN chmod +x /opt/microsoft/powershell/7/pwsh
RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

# Tools as packages
RUN apt-get install -y -qq --no-install-recommends \
    helm \
    kubectl

RUN pwsh -NoProfile -NonInteractive -Command 'Install-Module PowerShellGet -Force -AllowClobber'
RUN pwsh -NoProfile -NonInteractive -Command 'Install-Module Microsoft.PowerShell.PSResourceGet -Repository PSGallery -Force'
RUN pwsh -NoProfile -NonInteractive -Command 'Install-Module -Name Oh-My-Posh,Posh-Git,PSReadLine,Terminal-Icons -Scope AllUsers -Repository PSGallery -Force'

# Use geekzter/bootstrap-os for PowerShell setup
RUN mkdir -p /home/vscode/src
RUN git clone https://github.com/geekzter/bootstrap-os.git /home/vscode/src/bootstrap-os
RUN /home/vscode/src/bootstrap-os/common/common_setup.ps1 -NoPackages

# Can be 'linux-x64', 'linux-arm64', 'linux-arm', 'rhel.6-x64'.
# ENV TARGETARCH=linux-x64
