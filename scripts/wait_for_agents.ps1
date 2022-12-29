#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Wait for Pipeline agents to come online
#> 
#Requires -Version 7.2

param ( 
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [String]
    $CapabilityName='PIPELINE_DEMO_JOB_CAPABILITY',

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [String]
    $CapabilityValue,
                    
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [String]
    $OrganizationUrl=($env:AZP_URL ?? $env:AZDO_ORG_SERVICE_URL),
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [int]
    $PoolId=1,

    [parameter(Mandatory=$false)]
    [int]
    $TimeoutSeconds=600
) 
Write-Host $MyInvocation.line

$stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch     
$stopWatch.Start()

do {
    az pipelines agent list --pool-id $PoolId `
                            --include-capabilities `
                            --org $OrganizationUrl `
                            --query "[?systemCapabilities.${CapabilityName}=='${CapabilityValue}'&&status=='online'].name" `
                            -o tsv `
                            | Set-Variable onlineAgentNames
} while (!$onlineAgentNames -and ($stopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds))

if ($onlineAgentNames) {
    "The following agent(s) is/are online in pool {1}: {0}" -f $onlineAgentNames, $PoolId | Write-Host 
} else {
    Write-Error "Could not find an online agent in pool ${PoolId} with capability ${CapabilityName}=='${CapabilityValue}'"
}