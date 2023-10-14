FROM ubuntu:20.04
ARG VSCODE_HOME=/home/vscode
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y -qq --no-install-recommends \
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
RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
    tee /etc/apt/sources.list.d/kubernetes.list

# Helm repo
RUN curl https://baltocdn.com/helm/signing.asc | \
    gpg --dearmor | \
    tee /usr/share/keyrings/helm.gpg > /dev/null && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
    tee /etc/apt/sources.list.d/helm-stable-debian.list

# Hashicorp repo
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

# Microsoft repos
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" && \
    dpkg -i packages-microsoft-prod.deb && \
    echo "deb [arch=`dpkg --print-architecture`] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/azure-cli.list

# Tools
RUN apt-get update && \
    apt-get install -y -qq --no-install-recommends \
    azure-cli\
    helm \
    kubectl \
    terraform \
    && az extension add -n azure-devops -y \
    && az extension add -n azure-firewall -y \
    && az extension add -n bastion -y \
    && az extension add -n containerapp -y \
    && az extension add -n resource-graph -y

# PowerShell, do not rely on apt as no arm64 package is available
ARG PS_VERSION=7.3.8
RUN PS_ARCH= && dpkgArch="$(dpkg --print-architecture)" \
    && case "${dpkgArch##*-}" in \
      amd64) PS_ARCH='x64';; \
      arm64) PS_ARCH='arm64';; \
      *) echo "unsupported architecture"; exit 1 ;; \
    esac && \
    PS_PACKAGE=powershell-${PS_VERSION}-linux-${PS_ARCH}.tar.gz && \
    PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE} && \
    echo $PS_PACKAGE_URL && \
    curl -L -o /tmp/powershell.tar.gz $PS_PACKAGE_URL && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    pwsh -NoProfile -NonInteractive -Command 'Install-Module PowerShellGet -Force -AllowClobber;Install-Module -Name Microsoft.PowerShell.PSResourceGet,Oh-My-Posh,Posh-Git,PSReadLine,Terminal-Icons -Scope AllUsers -Repository PSGallery -Force'

RUN mkdir -p ${VSCODE_HOME}/src \
    && git clone https://github.com/geekzter/bootstrap-os.git ${VSCODE_HOME}/src/bootstrap-os

