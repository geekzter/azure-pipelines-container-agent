#!/usr/bin/env pwsh
<# 
.SYNOPSIS 
    Deploys Azure resources using Terraform
 
.DESCRIPTION 
    This script is a wrapper around Terraform. It is provided for convenience only, as it works around some limitations in the demo. 
    E.g. terraform might need resources to be started before executing, and resources may not be accessible from the current locastion (IP address).

.EXAMPLE
    ./deploy.ps1 -apply
#> 
#Requires -Version 7.2

### Arguments
param ( 
    [parameter(Mandatory=$false,HelpMessage="Initialize Terraform backend, modules & provider")][switch]$Init=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform plan stage")][switch]$Plan=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform validate stage")][switch]$Validate=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform apply stage (implies plan)")][switch]$Apply=$false,
    [parameter(Mandatory=$false,HelpMessage="Perform Terraform destroy stage")][switch]$Destroy=$false,
    [parameter(Mandatory=$false,HelpMessage="Show Terraform output variables")][switch]$Output=$false,
    [parameter(Mandatory=$false,HelpMessage="Don't show prompts unless something get's deleted that should not be")][switch]$Force=$false,
    [parameter(Mandatory=$false,HelpMessage="Initialize Terraform backend, upgrade modules & provider")][switch]$Upgrade=$false,
    [parameter(Mandatory=$false,HelpMessage="Don't try to set up a Terraform backend if it does not exist")][switch]$NoBackend=$false
) 

if ($env:SYSTEM_DEBUG -eq "true") {
    $InformationPreference = "Continue"
    $VerbosePreference = "Continue"
    $DebugPreference = "Continue"

    Set-PSDebug -Trace 1
    
    Get-ChildItem -Path Env: -Force -Recurse -Include * | Sort-Object -Property Name | Format-Table -AutoSize | Out-String
}

### Internal Functions
. (Join-Path $PSScriptRoot functions.ps1)

### Validation
if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
    $tfMissingMessage = "Terraform not found`nInstall Terraform e.g. from https://www.terraform.io/downloads.html"
    throw $tfMissingMessage
}

Write-Information $MyInvocation.line 
$script:ErrorActionPreference = "Stop"

$workspace = Get-TerraformWorkspace
$planFile  = "${workspace}.tfplan".ToLower()
$varsFile  = "${workspace}.tfvars".ToLower()
$inAutomation = ($env:TF_IN_AUTOMATION -ieq "true")
if (($workspace -ieq "prod") -and $Force) {
    $Force = $false
    Write-Warning "Ignoring -Force in workspace '${workspace}'"
}

try {
    $tfdirectory = (Get-TerraformDirectory)
    Push-Location $tfdirectory
    # Print version info
    terraform -version

    if ($Init -or $Upgrade) {
        if (!$NoBackend) {
            $backendFile = (Join-Path $tfdirectory backend.tf)
            $backendTemplate = "${backendFile}.sample"
            $newBackend = (!(Test-Path $backendFile))
            $tfbackendArgs = ""
            $env:TF_STATE_backend_storage_account_name   ??= $env:TF_STATE_BACKEND_STORAGE_ACCOUNT_NAME
            $env:TF_STATE_backend_storage_container_name ??= $env:TF_STATE_BACKEND_STORAGE_CONTAINER_NAME
            $env:TF_STATE_backend_resource_group_name    ??= $env:TF_STATE_BACKEND_RESOURCE_GROUP_NAME
            if ($newBackend) {
                if (!$env:TF_STATE_backend_storage_account_name -or !$env:TF_STATE_backend_storage_container_name) {
                    Write-Warning "Environment variables TF_STATE_backend_storage_account_name and TF_STATE_backend_storage_container_name must be set when creating a new backend from $backendTemplate"
                    $fail = $true
                }
                if (!($env:TF_STATE_backend_resource_group_name -or $env:ARM_ACCESS_KEY -or $env:ARM_SAS_TOKEN)) {
                    Write-Warning "Environment variables ARM_ACCESS_KEY or ARM_SAS_TOKEN or TF_STATE_backend_resource_group_name (with Terraform identity granted 'Storage Blob Data Contributor' role) must be set when creating a new backend from $backendTemplate"
                    $fail = $true
                }
                if ($fail) {
                    Write-Warning "This script assumes Terraform backend exists at ${backendFile}, but it does not exist"
                    Write-Host "You can copy ${backendTemplate} -> ${backendFile} and configure a storage account manually"
                    Write-Host "See documentation at https://www.terraform.io/docs/backends/types/azurerm.html"
                    exit
                }

                # Terraform azurerm backend does not exist, create one
                Write-Host "Creating '$backendFile'"
                Copy-Item -Path $backendTemplate -Destination $backendFile
                
                $tfbackendArgs += " -reconfigure"
            }

            if ($env:TF_STATE_backend_resource_group_name) {
                $tfbackendArgs += " -backend-config=`"resource_group_name=${env:TF_STATE_backend_resource_group_name}`""
            }
            if ($env:TF_STATE_backend_storage_account_name) {
                $tfbackendArgs += " -backend-config=`"storage_account_name=${env:TF_STATE_backend_storage_account_name}`""
            }
            if ($env:TF_STATE_backend_storage_container_name) {
                $tfbackendArgs += " -backend-config=`"container_name=${env:TF_STATE_backend_storage_container_name}`""
            }
        }
        
        $initCmd = "terraform init $tfbackendArgs"
        if ($Upgrade) {
            $initCmd += " -upgrade"
        }
        Invoke "$initCmd" 
    }

    if ($Validate) {
        Invoke "terraform validate" 
    }
    
    # Prepare common arguments
    if ($Force) {
        $forceArgs = "-auto-approve"
    }

    if (!(Get-ChildItem Env:TF_VAR_* -Exclude TF_VAR_backend_*) -and (Test-Path $varsFile)) {
        # Load variables from file, if it exists and environment variables have not been set
        $varArgs = " -var-file='$varsFile'"
    }

    if ($Plan -or $Apply -or $Destroy) {
        Login-AzDO -DisplayMessages
        $resourceGroup = (Get-TerraformOutput resource_group_name)
        if ($resourceGroup) {
            Invoke-Command -ScriptBlock {
                $Private:ErrorActionPreference = "Continue"
                Write-Debug "az aks list -g $resourceGroup --subscription $env:ARM_SUBSCRIPTION_ID --query `"[?provisioningState=='Succeeded'&&properties.powerState.code!='Running'].name`""
                $aks = $(az aks list -g $resourceGroup --subscription $env:ARM_SUBSCRIPTION_ID --query "[?provisioningState=='Succeeded'&&properties.powerState.code!='Running'].name" -o tsv)
                if ($aks) {
                    az aks show -n $aks -g $resourceGroup --query powerState --subscription $env:ARM_SUBSCRIPTION_ID -o tsv | Set-Variable powerState
                    if ($powerState -ieq 'Running') {
                        Write-Host "AKS ${aks} nodes are already running."
                    } else {
                        Write-Host "AKS ${aks} nodes are not running. Starting..."
                        Write-Debug "az aks start -n $aks -g $resourceGroup"
                        az aks start -n $aks -g $resourceGroup --subscription $env:ARM_SUBSCRIPTION_ID --query "[].name" -o tsv
                        Write-Host "Started AKS '${aks}' in resource group '${resourceGroup}'"
                    }
                }
            }
        }
    }

    if ($Plan -or $Apply) {
        # Create plan
        Invoke "terraform plan $varArgs -out='$planFile'"
    }

    if ($Apply) {
        if (!$inAutomation) {
            $defaultChoice = 0

            if (!$Force) {
                # Prompt to continue
                $choices = @(
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Continue", "Deploy infrastructure")
                    [System.Management.Automation.Host.ChoiceDescription]::new("&Exit", "Abort infrastructure deployment")
                )
                $decision = $Host.UI.PromptForChoice("Continue", "Do you wish to proceed executing Terraform plan $planFile in workspace $workspace?", $choices, $defaultChoice)

                if ($decision -eq 0) {
                    Write-Host "$($choices[$decision].HelpMessage)"
                } else {
                    Write-Host "$($PSStyle.Formatting.Warning)$($choices[$decision].HelpMessage)$($PSStyle.Reset)"
                    exit                    
                }
            }
        }

        Invoke "terraform apply $forceArgs '$planFile'"
    }

    if ($Output) {
        Invoke "terraform output"

        if (![string]::IsNullOrEmpty($env:AGENT_VERSION)) {
            # Export Terraform output as Pipeline output variables for subsequent tasks
            Set-PipelineVariablesFromTerraform
        }       
    }


    if ($Destroy) {
        Invoke "terraform destroy $varArgs $forceArgs"
    }
} finally {
    Pop-Location
}