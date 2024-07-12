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

RUN apt-get update

# Hashicorp packages
RUN apt-get install -y packer

# Tools as packages
RUN apt-get install -y -qq --no-install-recommends \
    ansible \
    python2-minimal \
    unzip

# Microsoft packages
RUN apt-get install -y azure-functions-core-tools \
                       dotnet-sdk-6.0 \
                       dotnet-sdk-8.0

RUN pwsh -NoProfile -NonInteractive -Command 'Install-Module -Name Az,Microsoft.Graph,SqlServer -Scope AllUsers -Repository PSGallery -Force'

# Can be 'linux-x64', 'linux-arm64', 'linux-arm', 'rhel.6-x64'.
ENV TARGETARCH=linux-x64
