#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    This script creates/updates dashboard.tpl with updates made to the dashboard in the Azure Portal
.DESCRIPTION 
    This template updated/created (dashboard.tpl) is a Terraform template. This script will replace literals with template tokens as needed, such that new deployments will use values pertaining to that deployment.
#> 
#Requires -Version 7

param ( 
    [parameter(Mandatory=$false)][string]$InputFile,
    [parameter(Mandatory=$false)][string]$OutputFile="dashboard.template.json",
    [parameter(Mandatory=$false)][string]$Workspace=$env:TF_WORKSPACE,
    [parameter(Mandatory=$false)][switch]$Force=$false,
    [parameter(Mandatory=$false)][switch]$ShowTemplate=$false,
    [parameter(Mandatory=$false)][switch]$SkipWrite=$false,
    [parameter(Mandatory=$false)][string]$subscription=$env:ARM_SUBSCRIPTION_ID
) 


### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)
$tfdirectory = $(Join-Path (Get-Item $PSScriptRoot).Parent.FullName "terraform")
$inputFilePath  = Join-Path $tfdirectory $InputFile
$outputFilePath = Join-Path $tfdirectory $OutputFile


if (!(Test-Path $inputFilePath)) {
    Write-Host "$inputFilePath not found" -ForegroundColor Red
    exit
}

# Retrieve Azure resources config using Terraform
try {
    Push-Location $tfdirectory

    $acaPoolUrl          = (Get-TerraformOutput "aca_agent_pool_url")
    $aksPoolUrl          = (Get-TerraformOutput "aks_agent_pool_url")
    $containerRegistryID = (Get-TerraformOutput "container_registry_id")
    $dashboardID         = (Get-TerraformOutput "portal_dashboard_id")
    $location            = (Get-TerraformOutput "location")
    $logAnalyticsID      = (Get-TerraformOutput "log_analytics_workspace_resource_id")
    $pipelinePoolUrl     = (Get-TerraformOutput "pipeline_agent_pool_url")
    $resourceGroupID     = (Get-TerraformOutput "resource_group_id")
    $suffix              = (Get-TerraformOutput "resource_suffix")
    $storageAccountName  = (Get-TerraformOutput "diagnostics_storage_account_name")
    $subscriptionGUID    = (Get-TerraformOutput "subscription_guid")
    $workspace           = (Get-TerraformOutput "workspace")

    if ([string]::IsNullOrEmpty($dashboardID) -or [string]::IsNullOrEmpty($subscriptionGUID) -or [string]::IsNullOrEmpty($suffix)) {
        Write-Warning "Resources have not yet been, or are being created. Nothing to do"
        exit 
    }
} finally {
    Pop-Location
}

$dashboardName     = $dashboardID.Split("/")[8]
$resourceGroupName = $resourceGroupID.Split("/")[4]
if ($InputFile) {
    Write-Host "Reading from file $InputFile..." -ForegroundColor Green
    $template = (Get-Content $inputFilePath -Raw) 
    $template = $($template | jq '.properties') # Use jq, ConvertFrom-Json does not parse properly
} else {
    Write-Host "Retrieving resource $dashboardID..." -ForegroundColor Green
    # $template = (az resource show --ids $dashboardID --query "properties" -o json --subscription $subscr)
    if (!(az extension list --query "[?name=='portal'].version" -o tsv)) {
        Write-Host "Adding Azure CLI extension 'portal'..."
        az extension add -n portal -y
    }    
    Write-Debug "az portal dashboard show -n $dashboardName -g $resourceGroupName -o json --subscription $subscriptionGUID"
    $template = (az portal dashboard show -n $dashboardName -g $resourceGroupName -o json --subscription $subscriptionGUID)
}

if ($aca_agent_pool_url) {
    # $template = $template -Replace "https://dev.azure.com[^`']*_settings/agentpools[^`']*`'", "`$`{aca_agent_pool_url`}`'"
    $template = $template -Replace "${aca_agent_pool_url}", "`$`{aca_agent_pool_url`}`'"
}
if ($aks_agent_pool_url) {
    $template = $template -Replace "${aks_agent_pool_url}", "`$`{aks_agent_pool_url`}`'"
}
if ($containerRegistryID) {
    $template = $template -Replace "${containerRegistryID}", "`$`{container_registry_id`}" 
}
if ($logAnalyticsID) {
    $template = $template -Replace "${logAnalyticsID}", "`$`{log_analytics_workspace_resource_id`}" 
}
if ($resourceGroupID) {
    $template = $template -Replace "${resourceGroupID}", "`$`{resource_group_id`}"
}
if ($resourceGroupName) {
    $template = $template -Replace "${resourceGroupName}", "`$`{resource_group`}"
}
$template = $template -Replace "/subscriptions/........-....-....-................./", "`$`{subscription_id`}/"
if ($subscriptionGUID) {
    $template = $template -Replace "${subscriptionGUID}", "`$`{subscription_guid`}"
}
if ($location) {
    $template = $template -Replace "${location}", "`$`{location`}"
}
if ($storageAccountName) {
    $template = $template -Replace "${storageAccountName}", "`$`{storage_account_name`}"
}
if ($suffix) {
    $template = $template -Replace "-${suffix}", "-`$`{suffix`}"
    $template = $template -Replace "\`'${suffix}\`'", "'`$`{suffix`}'"
    $template = $template -Replace "${suffix}/", "`$`{suffix`}/"
    $template = $template -Replace "${suffix}`"", "`$`{suffix`}`""
}
if ($workspace) {
    $template = $template -Replace "-${workspace}-", "-`$`{workspace`}-"
    $template = $template -Replace "\`"${workspace}\`"", "`"`$`{workspace`}`""
    $template = $template -Replace "(${workspace})", "(`$`{workspace`})"
}
if ($workspace -and $suffix) {
    $template = $template -Replace "${workspace}${suffix}", "`$`{workspace`}`$`{suffix`}"
}

$template = $template -Replace "[\w]*\.portal.azure.com", "portal.azure.com"
$template = $template -Replace "@\w+.onmicrosoft.com", "@"

# Check for remnants of tokens that should've been caught
$subscriptionGUIDMatches = $template -match $subscriptionGUID
if ($subscriptionGUIDMatches) {
    Write-Warning "Subscription GUID '$subscriptionGUID' found in output:"
    $subscriptionGUIDMatches
}
$suffixMatches = $template -match $suffix
if ($suffixMatches) {
    Write-Warning "Suffix value '$suffix' found in output:"
    $suffixMatches
}
$workspaceMatches = $template -match "${workspace}[^\w]"
if ($workspaceMatches) {
    Write-Warning "Workspace name value '$workspace' found in output:"
    $workspaceMatches
}
if ($subscriptionGUIDMatches -or $suffixMatches -or $workspaceMatches) {
    Write-Debug "subscriptionGUIDMatches: $subscriptionGUIDMatches"
    Write-Debug "suffixMatches: $suffixMatches"
    Write-Debug "workspaceMatches: $workspaceMatches"
    Write-Host "Aborting" -ForegroundColor Red
    exit 1
}

# Remove metadata provided by Terraform azurerm at provisioning time
$template | ConvertFrom-Json -Depth 100 -AsHashtable | Set-Variable templateObject
$templateObject.Remove("name")
$templateObject.Remove("resourceGroup")
$templateObject.Remove("tags")
$templateObject.Remove("type")
$templateObject | ConvertTo-Json -Depth 100 | Set-Variable template

if ($SkipWrite) {
    Write-Warning "Skipped writing template" -ForegroundColor Yellow
} else {
    $defaultChoice = $Force ? 0 : 1
    if ((Test-Path $outputFilePath) -and !$Force) {
        Write-Warning "$outputFilePath already exists"
        # Prompt to continue
        $choices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new("&Continue", "Overwrite file")
            [System.Management.Automation.Host.ChoiceDescription]::new("&Exit", "Leave template unchanged")
        )
        $decision = $Host.UI.PromptForChoice("Continue", "Do you wish to overwrite template ${outputFilePath}?", $choices, $defaultChoice)
    
        if ($decision -eq 0) {
            Write-Host "$($choices[$decision].HelpMessage)"
        } else {
            Write-Host "$($PSStyle.Formatting.Warning)$($choices[$decision].HelpMessage)$($PSStyle.Reset)"
            exit                    
        }
    }

    $template | Out-File $outputFilePath
    Write-Host "Saved template to $outputFilePath"
}
if ($ShowTemplate) {
    Write-Host $template
}