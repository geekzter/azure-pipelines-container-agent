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

    [Parameter(Mandatory=$true,ParameterSetName='ResourceGroup')]
    [ValidateNotNull()]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory=$false,ParameterSetName='ResourceGroup')]
    [ValidateNotNull()]
    [string]
    $SubscriptionId=($env:AZURE_SUBSCRIPTION_ID),

    [Parameter(Mandatory=$true,ParameterSetName='ResourceGraph')]
    [ValidateNotNull()]
    [string]
    $AgentPoolName,

    [Parameter(Mandatory=$false)]
    [switch]
    $Wait
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
    $AksName = $(az aks list -g $ResourceGroupName --subscription $SubscriptionId --query "[0].name" -o tsv)
}
if ($AksId) {
    $AksIdElements = $AksId.Split('/')
    if ($AksIdElements.Count -ne 9) {
        Write-Warning "Invalid AKS resource id: $AksId"
        exit 1
    }
    $AksName = $AksIdElements.Split('/')[8]
    $ResourceGroupName = $AksIdElements.Split('/')[4]
    $SubscriptionId = $AksIdElements.Split('/')[2]    
}
$SubscriptionId ??= (az account show --query id -o tsv)

# Get latest AKS state (resource graph may be out of date)
az aks show -n $AksName `
            -g $ResourceGroupName `
            --subscription $SubscriptionId `
            -o json `
            | ConvertFrom-Json `
            | Set-Variable aks

$aks | Format-List | Out-String | Write-Debug

if ($aks.provisioningState -inotin "Stopping", "Succeeded") {
    "AKS '${AksName}' is in '{0}' state" -f $aks.provisioningState | Write-Error
    exit 1
}
if ($aks.powerState.code -iin "Running", "Starting") {
    "AKS '${AksName}' is already in '{0}' state" -f $aks.powerState.code | Write-Host
    exit 0
}
"AKS '${AksName}' is in provisioning state '{0}' and power state '{1}'" -f $aks.provisioningState, $aks.powerState.code | Write-Debug

az aks show -n $AksName -g $ResourceGroupName --query powerState --subscription $SubscriptionId -o tsv | Set-Variable powerState
if ($powerState -ieq 'Running') {
    Write-Host "AKS $(AksName) nodes are already running."
} else {
    Write-Host "Starting AKS '${AksName}' in resource group '${ResourceGroupName}'..."
    Write-Debug "az aks start -n $AksName -g $ResourceGroupName --subscription $SubscriptionId"
    az aks start -n $AksName -g $ResourceGroupName --subscription $SubscriptionId --no-wait
    if ($Wait) {
        az aks start -n $AksName -g $ResourceGroupName --subscription $SubscriptionId
    }
}