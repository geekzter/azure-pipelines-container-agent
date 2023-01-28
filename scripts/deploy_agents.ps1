#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Install KEDA
#> 
#Requires -Version 7.2

param ( 
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNull()]
    [string]
    $AksId,

    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNull()]
    [string]
    $DiagnosticsShareAccountName,

    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNull()]
    [string]
    $DiagnosticsShareAccountKey,

    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNull()]
    [string]
    $ResourceGroupName,

    [switch]
    $InstallKeda,

    [switch]
    $DryRun    
) 

if (!(Get-Command az)) {
    Write-Warning "Azure CLI is not installed, get it at http://aka.ms/azure-cli"
    exit 1
}
if (!(Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Warning "helm not found. Get it at https://helm.sh/docs/intro/install"
    exit 1
}
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Warning "kubectl not found. Installing using Azure CLI..."
    az aks install-cli
}

$AksIdElements = $AksId.Split('/')
if ($AksIdElements.Count -ne 9) {
    Write-Warning "Invalid AKS resource id: $AksId"
    exit 1
}
$aksClusterName = $AksIdElements.Split('/')[8]
Write-Verbose "AKS cluster name: $aksClusterName"
$aksResourceGroup = $AksIdElements.Split('/')[4]
Write-Verbose "AKS resource group: $aksResourceGroup"
$aksSubscription = $AksIdElements.Split('/')[2]
Write-Verbose "AKS subscription: $aksSubscription"

kubectl config current-context | Set-Variable currentContext
if (!$currentContext.StartsWith($aksClusterName)) {
    Write-Host "Setting kubectl context to $aksClusterName"
    Write-Debug "az aks get-credentials --resource-group $aksResourceGroup --name $aksClusterName --subscription $aksSubscription -a"
    az aks get-credentials --resource-group $aksResourceGroup --name $aksClusterName --subscription $aksSubscription -a
}

if ($InstallKeda) {
    # Install KEDA
    # https://keda.sh/docs/2.9/deploy/
    Write-Host "`nConfiguring KEDA..."
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    kubectl create namespace keda 2>$null
    helm install keda kedacore/keda --namespace keda
}

$helmDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) helm pipeline-keda-agents)

# /usr/local/bin/helm upgrade --install --values /home/vsts/work/1/s/helm/pipeline-keda-agents/values.yaml --set image.repository=ericvanimages.azurecr.io/pipelineagent/ubuntu,linux.azureDevOps.accessToken=dndspdevmrixmnugzbvx6xkhn77jvdgxyywanemwiorod6qltuoq,linux.azureDevOps.orgUrl=https://dev.azure.com/ericvan/,linux.azureDevOps.capability=https://dev.azure.com/ericvan/PipelineAgents#deploy-container-agents#cd#aks,linux.azureDevOps.poolName=Default,linux.image.acrLoginServer=ericvanimages,linux.trigger.poolId=1 --wait pipeline-keda-agents /home/vsts/work/1/s/helm/pipeline-keda-agents

Push-Location $helmDirectory
$psNativeCommandArgumentPassingBackup = $PSNativeCommandArgumentPassing
try {
    $PSNativeCommandArgumentPassing = "Legacy"
    helm upgrade --install azure-pipeline-keda-agents . `
                 --values ./values.yaml,./__local/values.yaml `
                 --set storage.accountName=${DiagnosticsShareAccountName},storage.accountKey=${DiagnosticsShareAccountKey},storage.resourceGroupName=${ResourceGroupName} `
                 ($DryRun ? "--dry-run" : "")
} finally {
    $PSNativeCommandArgumentPassing = $psNativeCommandArgumentPassingBackup
    Pop-Location
}
