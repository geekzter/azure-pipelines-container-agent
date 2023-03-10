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
    $ImageName="ubuntu",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Repository="pipelineagent",

    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $Platform="linux/amd64",

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
    $Token=($env:AZP_TOKEN ?? $env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN),

    [parameter(Mandatory=$false)]
    [switch]
    $RunOnce=$false
) 

. (Join-Path $PSScriptRoot functions.ps1)


Start-Docker
Write-Host "Starting container agent with name '${AgentName}'..."
docker run --platform $Platform `
           -e AZP_AGENT_NAME=$AgentName `
           -e AZP_POOL=$PoolName `
           -e AZP_TOKEN=$Token `
           -e AZP_URL=$OrganizationUrl `
           ${Repository}/${ImageName} `
           ($RunOnce ? "--once" : "")
