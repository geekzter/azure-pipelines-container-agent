ARG BASE_IMAGE=pipelineagent/ubuntu-dev-tools:latest
FROM ${BASE_IMAGE}
ENV DEBIAN_FRONTEND=noninteractive

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

RUN apt-get update

# Hashicorp packages
RUN apt-get install -y packer

# Tools as packages
RUN apt-get install -y -qq --no-install-recommends \
    ansible \
    helm \
    kubectl \
    python2-minimal \
    unzip

# Microsoft packages
RUN apt-get install -y azure-functions-core-tools \
                       dotnet-sdk-6.0 \
                       dotnet-sdk-7.0

RUN pwsh -NoProfile -NonInteractive -Command 'Install-Module -Name Az,Microsoft.Graph,SqlServer -Scope AllUsers -Repository PSGallery -Force'

# Can be 'linux-x64', 'linux-arm64', 'linux-arm', 'rhel.6-x64'.
ENV TARGETARCH=linux-x64
