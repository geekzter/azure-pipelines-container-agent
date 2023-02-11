#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Remove offline agents from an Azure Pipelines agent pool
#> 
#Requires -Version 7.2

param ( 
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string[]]
    $PoolName,
                
    [Parameter(Mandatory=$false)]
    [ValidateNotNull()]
    [string]
    $OrganizationUrl=($env:AZP_URL ?? $env:AZDO_ORG_SERVICE_URL),

    [parameter(Mandatory=$false,HelpMessage="PAT token with read access on 'Agent Pools' scope")]
    [ValidateNotNull()]
    [string]
    $Token=($env:AZURE_DEVOPS_EXT_PAT ?? $env:AZDO_PERSONAL_ACCESS_TOKEN)
) 

Write-Verbose $MyInvocation.line

### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

if (!(Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Warning "Azure CLI not found. Please install it."
    exit 1
}
if (!(az extension list --query "[?name=='azure-devops'].version" -o tsv)) {
    Write-Host "Adding Azure CLI extension 'azure-devops'..."
    az extension add -n azure-devops -y
}

$Token | az devops login --organization $OrganizationUrl
az devops configure --defaults organization=$OrganizationUrl

foreach ($pool in ($PoolName | Get-Unique)) {
    az pipelines pool list --pool-name "${pool}" --query "[].id" -o tsv | Set-Variable poolId

    if (!$poolId) {
        Write-Warning "Pool '${pool}' not found, nothing to delete."
        continue
    }
    
    Remove-AgentPool -PoolId $poolId -Token $Token -OrganizationUrl $OrganizationUrl
}