#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Used in a pipeline to configure Terraform azapi/azurerm providers inside a AzureCLI task.
    See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli
#> 
#Requires -Version 7

if (Get-Command az -ErrorAction SilentlyContinue) {
    # Get from Azure CLI context
    az account show 2>$null | ConvertFrom-Json | Set-Variable account
    if ($account) {
        $env:ARM_TENANT_ID       ??= $account.tenantId
        $env:ARM_SUBSCRIPTION_ID ??= $account.id    
    } else {
        Write-Warning "Not logged into Azure CLI, no context to propagate as ARM_TENANT_ID & ARM_SUBSCRIPTION_ID environment variables"
    }
} else {
    Write-Warning "Azure CLI not found, no context to propagate as ARM_TENANT_ID & ARM_SUBSCRIPTION_ID environment variables"
}

$pipeline = ![string]::IsNullOrEmpty($env:AGENT_VERSION)
if ($pipeline) {
    # Propagate pipeline Service Principal as Terraform variables
    $env:ARM_CLIENT_ID       ??= $env:servicePrincipalId
    $env:ARM_CLIENT_SECRET   ??= $env:servicePrincipalKey
    $env:ARM_TENANT_ID       ??= $env:tenantId
} else {
    Write-Warning "Not in a pipeline, no context to propagate as ARM_CLIENT_ID & ARM_CLIENT_SECRET environment variables"
}

Write-Host "The following variables have been set:"
Get-ChildItem -Path Env: -Recurse -Include ARM_* | Sort-Object -Property Name `
                                                 | Format-Table -HideTableHeaders -Property Name