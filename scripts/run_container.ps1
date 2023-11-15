#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Runs the container agent locally

.EXAMPLE
    ./run_container.ps1 -OrganizationUrl https://dev.azure.com/<myorg> -Token <pat>
#> 
#Requires -Version 7.2
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $ImageName="ubuntu-dev-tools",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Repository="localhost/pipelineagent",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $AgentName=($env:AZP_AGENT_NAME ?? "$([Environment]::MachineName)-Ubuntu-$((Get-Date).ToString("yyyyMMddhhmmss"))"),
    
    [parameter(Mandatory=$false)]
    [string]
    $PoolName=$env:AZP_POOL ?? "Default",
    
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $OrganizationUrl=($env:AZP_URL ?? $env:AZDO_ORG_SERVICE_URL),
    
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Token=($env:AZP_TOKEN ?? $env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN)
) 

. (Join-Path $PSScriptRoot functions.ps1)

Start-ContainerEngine
Write-Host "Starting container agent image ${Repository}/${ImageName} with name '${AgentName}'..."
docker run -e AZP_AGENT_NAME=${AgentName} `
           -e AZP_POOL=${PoolName} `
           -e AZP_TOKEN=${Token} `
           -e AZP_URL=${OrganizationUrl} `
           -it `
           ${Repository}/${ImageName} `
           /bin/bash
