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
    $AksId
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
$aksResourceGroup = $AksIdElements.Split('/')[4]
$aksSubscription = $AksIdElements.Split('/')[2]

kubectl config current-context | Set-Variable currentContext
if (!$currentContext.StartsWith($aksClusterName)) {
    Write-Host "Setting kubectl context to $aksClusterName"
    az aks get-credentials --resource-group $aksResourceGroup --name $aksClusterName --subscription $aksSubscription -a
}

# Install KEDA
# https://keda.sh/docs/2.9/deploy/
Write-Host "`nConfiguring KEDA..."
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda 2>$null
helm install keda kedacore/keda --namespace keda

$helmDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) helm pipeline-keda-agents)

Push-Location $helmDirectory
helm upgrade --install azure-pipeline-keda-agents . -f ./values.yaml,./__local/values.yaml
Pop-Location