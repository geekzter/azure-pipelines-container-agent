#!/usr/bin/env pwsh

#Requires -Version 7.2
param ( 
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $ImageName="dockeragent:latest",
    
    [parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $AgentName=($env:AZP_AGENT_NAME ?? "Ubuntu-$((Get-Date).ToString("yyyyMMddhhmmss"))"),
    
    [parameter(Mandatory=$false)]
    [string]
    $PoolName=$env:AZP_POOL,
    
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

docker run --platform linux/amd64 `
           -e AZP_AGENT_NAME=$AgentName `
           -e AZP_POOL=$PoolName `
           -e AZP_TOKEN=$Token `
           -e AZP_URL=$OrganizationUrl `
           $ImageName `
           ($RunOnce ? "--once" : "")
