#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Install KEDA
#> 
#Requires -Version 7.2

param ( 
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $AksId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $DiagnosticsShareAccountName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $DiagnosticsShareAccountKey,

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [int]
    $PoolId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [string]
    $PoolName,

    $Suffix,

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

Push-Location $helmDirectory
$psNativeCommandArgumentPassingBackup = $PSNativeCommandArgumentPassing
try {
    $PSNativeCommandArgumentPassing = "Legacy"

    Join-Path (Split-Path $PSScriptRoot -Parent) `
              data `
              $env:TF_WORKSPACE helm-env-vars-values.json `
              | Set-Variable helmEnvVarsValuesFile
    $valueFiles = "./values.yaml,./__local/values.yaml"
    if (Test-Path $helmEnvVarsValuesFile) {
        $valueFiles += ",${helmEnvVarsValuesFile}"
    } else {
        Write-Warning "No helm-env-vars-values.json file found at ${helmEnvVarsValuesFile}, skipping environment variable values"
    }

    helm upgrade --install azure-pipeline-keda-agents . `
                 --values ${valueFiles} `
                 --set linux.azureDevOps.poolName=${PoolName},linux.podPrefix=aks-${env:TF_WORKSPACE}-${Suffix},linux.trigger.poolId=${PoolId},storage.accountName=${DiagnosticsShareAccountName},storage.accountKey=${DiagnosticsShareAccountKey},storage.resourceGroupName=${ResourceGroupName} `
                 ($DryRun ? "--dry-run" : "")
} finally {
    $PSNativeCommandArgumentPassing = $psNativeCommandArgumentPassingBackup
    Pop-Location
}
