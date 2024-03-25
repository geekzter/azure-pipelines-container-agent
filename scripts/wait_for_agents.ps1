#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Wait for Pipeline agents to come online
#> 
#Requires -Version 7.2

param ( 
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $CapabilityName='PIPELINE_DEMO_JOB_CAPABILITY',

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $CapabilityValue,
                    
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $OrganizationUrl=($env:AZP_URL ?? $env:AZDO_ORG_SERVICE_URL),
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [int]
    $PoolId=1,

    [parameter(Mandatory=$false)]
    [int]
    $TimeoutSeconds=600
) 

function Find-Agent () {
    az pipelines agent list --pool-id $PoolId `
                            --include-capabilities `
                            --org $OrganizationUrl `
                            --query "[?systemCapabilities.${CapabilityName}=='${CapabilityValue}'&&status=='online'].name" `
                            -o tsv `
                            | Set-Variable onlineAgentNames

    return $onlineAgentNames
}

Write-Host $MyInvocation.line
. (Join-Path $PSScriptRoot functions.ps1)

if (!(Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Warning "Azure CLI not found. Please install it."
    exit 1
}
if (!(az extension list --query "[?name=='azure-devops'].version" -o tsv)) {
    Write-Host "Adding Azure CLI extension 'azure-devops'..."
    az extension add -n azure-devops -y
}

Login-AzDO -OrganizationUrl $OrganizationUrl

$stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch     
$stopWatch.Start()
Write-Host "Waiting for agents to come online." -NoNewLine
Find-Agent | Set-Variable onlineAgentNames
while (!$onlineAgentNames -and ($stopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds)) {
    Write-Host "." -NoNewLine
    Start-Sleep -Seconds 1
    Find-Agent | Set-Variable onlineAgentNames
} 

if ($onlineAgentNames) {
    Write-Host "✓" # Force NewLine
    "The following agent(s) is/are online in pool {1}: {0}" -f $onlineAgentNames, $PoolId | Write-Host 
} else {
    Write-Host "✘" # Force NewLine
    Write-Error "Could not find an online agent in pool ${PoolId} with capability ${CapabilityName}=='${CapabilityValue}'"
}