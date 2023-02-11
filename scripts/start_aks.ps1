#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Start AKS cluster
#> 
#Requires -Version 7.2

param ( 
    [Parameter(Mandatory=$true,ParameterSetName='ResourceId')]
    [ValidateNotNull()]
    [string]
    $AksId,

    [Parameter(Mandatory=$true,ParameterSetName='ResourceGraph')]
    [ValidateNotNull()]
    [string]
    $AgentPoolName
) 

if (!(Get-Command az)) {
    Write-Warning "Azure CLI is not installed, get it at http://aka.ms/azure-cli"
    exit 1
}

if ($AksId) {
    Write-Verbose "AKS resource id provided: ${AksId}"
} elseif ($AgentPoolName) {
    if (!(az extension list --query "[?name=='resource-graph'].version" -o tsv)) {
        Write-Host "Adding Azure CLI extension 'resource-graph'..."
        az extension add -n resource-graph -y
    }
    az graph query -q "resources | where type =~ 'Microsoft.ContainerService/managedClusters' and tags.pipelineAgentPoolName =~ '${AgentPoolName}'" `
                   -a `
                   --query "data" `
                   -o json `
                   | ConvertFrom-Json `
                   | Set-Variable aks
    if ($aks -eq $null) {
        Write-Error "No AKS found with tag 'pipelineAgentPoolName=${AgentPoolName}'"
        exit 1
    }
    $AksId = $aks.id
    Write-Verbose "AKS resource id found  with tag 'pipelineAgentPoolName=${AgentPoolName}': ${AksId}"
} else {
    Write-Warning "Either AKS resource id or agent pool name must be provided"
    exit 1
}

$AksIdElements = $AksId.Split('/')
if ($AksIdElements.Count -ne 9) {
    Write-Warning "Invalid AKS resource id: $AksId"
    exit 1
}
$aksClusterName = $AksIdElements.Split('/')[8]
$aksResourceGroup = $AksIdElements.Split('/')[4]
$aksSubscription = $AksIdElements.Split('/')[2]

# Get latest AKS state (resource graph may be out of date)
az aks show -n $aksClusterName `
            -g $aksResourceGroup `
            --subscription $aksSubscription `
            -o json `
            | ConvertFrom-Json `
            | Set-Variable aks

$aks | Format-List | Out-String | Write-Debug

if ($aks.provisioningState -inotin "Stopping", "Succeeded") {
    "AKS '${aksClusterName}' is in '{0}' state" -f $aks.provisioningState | Write-Error
    exit 1
}
if ($aks.powerState.code -iin "Running", "Starting") {
    "AKS '${aksClusterName}' is already in '{0}' state" -f $aks.powerState.code | Write-Error
    exit 0
}

Write-Host "Starting AKS '${aksClusterName}' in resource group '${aksResourceGroup}'..."
Write-Debug "az aks start -n $aksClusterName -g $aksResourceGroup --subscription $aksSubscription"
az aks start -n $aksClusterName -g $aksResourceGroup --subscription $aksSubscription --no-wait