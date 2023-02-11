#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Configure kubectl context to the AKS cluster
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

az aks show -n $aksClusterName `
            -g $aksResourceGroup `
            --subscription $aksSubscription `
            -o json `
            | ConvertFrom-Json `
            | Set-Variable aks

$aks | Format-List | Out-String | Write-Debug

if ($aks.provisioningState -ne "Succeeded") {
    Write-Error "AKS '${aksClusterName}' is not in 'Succeeded' state"
    exit 1
}
if ($aks.powerState.code -eq "Running") {
    Write-Host "AKS '${aksClusterName}' is already in 'Running' state"
    exit 0
}

Write-Host "Starting AKS '${aks}' in resource group '${resourceGroup}'..."
Write-Debug "az aks start -n $aks -g $resourceGroup --subscription $aksSubscription"
az aks start -n $aksClusterName -g $aksResourceGroup --subscription $aksSubscription --no-wait