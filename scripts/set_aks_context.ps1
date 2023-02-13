#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Configure kubectl context to the AKS cluster
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
if (!(Get-Command kubelogin -ErrorAction SilentlyContinue)) {
    Write-Warning "kubelogin not found. Installing using Azure CLI..."
    az aks install-cli
}
kubelogin convert-kubeconfig -l azurecli # Inherit Azure CLI token for K8s AAD RBAC

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
