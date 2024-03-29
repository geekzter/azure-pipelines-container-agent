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
    $OrganizationUrl=($env:AZP_URL ?? $env:AZDO_ORG_SERVICE_URL)
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

Login-AzDO -DisplayMessages:$false -OrganizationUrl $OrganizationUrl

foreach ($pool in ($PoolName | Get-Unique)) {
    az pipelines pool list --pool-name "${pool}" --query "[].id" -o tsv | Set-Variable poolId

    if (!$poolId) {
        Write-Warning "Pool '${pool}' not found, nothing to delete."
        continue
    }
    if ($poolId -eq 1) {
        Write-Warning "Pool '${pool}' is the default pool, skipping delete operation."
        continue
    }
    
    Remove-AgentPool -PoolId $poolId -Token $env:AZURE_DEVOPS_EXT_PAT -OrganizationUrl $OrganizationUrl
}