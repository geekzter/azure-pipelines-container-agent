$apiVersion = "7.1-preview.1"

function Create-RequestHeaders (
    [parameter(Mandatory=$true)][string]$Token
)
{
    $base64AuthInfo = [Convert]::ToBase64String([System.Text.ASCIIEncoding]::ASCII.GetBytes(":${Token}"))
    $authHeader = "Basic $base64AuthInfo"
    Write-Debug "Authorization: $authHeader"
    $requestHeaders = @{
        Accept = "application/json"
        Authorization = $authHeader
        "Content-Type" = "application/json"
    }

    return $requestHeaders
}

function Get-Agents(
    [parameter(Mandatory=$true)][int]$PoolId
) {
    az pipelines agent list --pool-id $poolId `
                            --org $OrganizationUrl `
                            --query "[?status=='offline'].id" `
                            -o tsv `
                            | Set-Variable offlineAgentIds

    return $offlineAgentIds
}

function Get-ContainerEngine() {
    Get-Alias Docker -ErrorAction SilentlyContinue | Set-Variable dockerAlias

    switch ($dockerAlias.Definition) {
        "podman" {
            return "podman"
        }
        default {
            return "docker"
        }
    }
}

function Get-DevContainerConfigPath () {
    $defaultContainerConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) .devcontainer devcontainer.json)
    switch (Get-ContainerEngine) {
        "podman" {
            $jsonDepth = 6
            $podmanContainerConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) .devcontainer podman devcontainer.json)
            New-Item -ItemType Directory -Force -Path $(Split-Path $podmanContainerConfigPath -Parent) | Out-Null
            Get-Content $defaultContainerConfigPath | ConvertFrom-Json -Depth $jsonDepth | Set-Variable devcontainer
            $devcontainer.build.dockerfile = "../$($devcontainer.build.dockerfile)"
            $devcontainer.runArgs = [System.Collections.Arraylist]::New($devcontainer.runArgs)
            $devcontainer.runArgs.Add("--userns=keep-id:uid=1000,gid=1000") | Out-Null
            $devcontainer | ConvertTo-Json -Depth $jsonDepth | Set-Content -Path $podmanContainerConfigPath -Force
            return $podmanContainerConfigPath
        }
        default {
            return $defaultContainerConfigPath
        }
    }
}

function Get-TerraformDirectory {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) "terraform")
}

function Get-TerraformOutput (
    [parameter(Mandatory=$true)][string]$OutputVariable
) {
    Invoke-Command -ScriptBlock {
        $Private:ErrorActionPreference = "SilentlyContinue"
        Write-Verbose "terraform output -raw ${OutputVariable}: evaluating..."
        $result = $(terraform output -raw $OutputVariable 2>$null)
        if ($result -match "\[\d+m") {
            # Terraform warning, return null for missing output
            Write-Verbose "terraform output ${OutputVariable}: `$null (${result})"
            return $null
        } else {
            Write-Verbose "terraform output ${OutputVariable}: ${result}"
            return $result
        }
    }
}

function Get-TerraformWorkspace () {
    Push-Location (Get-TerraformDirectory)
    try {
        return $(terraform workspace show)
    } finally {
        Pop-Location
    }
}

function Invoke (
    [string]$cmd
) {
    Write-Host "`n$cmd" -ForegroundColor Green 
    Invoke-Expression $cmd
    Validate-ExitCode $cmd
}

function Login-Az (
    [parameter(Mandatory=$false)][switch]$DisplayMessages=$false
) {
    if (!(Get-Command az)) {
        Write-Warning "Azure CLI is not installed, get it at http://aka.ms/azure-cli"
        exit
    }

    # Are we logged in? If so, is it the right tenant?
    $azureAccount = $null
    az account show 2>$null | ConvertFrom-Json | Set-Variable azureAccount
    if ($azureAccount -and "${env:ARM_TENANT_ID}" -and ($azureAccount.tenantId -ine $env:ARM_TENANT_ID)) {
        Write-Warning "Logged into tenant $($azureAccount.tenant_id) instead of $env:ARM_TENANT_ID (`$env:ARM_TENANT_ID)"
        $azureAccount = $null
    }
    if (-not $azureAccount) {
        if ($env:CODESPACES -ieq "true") {
            $azLoginSwitches = "--use-device-code"
        }
        if ($env:ARM_TENANT_ID) {
            az login -t $env:ARM_TENANT_ID -o none $($azLoginSwitches)
        } else {
            az login -o none $($azLoginSwitches)
        }
    }

    if ($env:ARM_SUBSCRIPTION_ID) {
        az account set -s $env:ARM_SUBSCRIPTION_ID -o none
    }

    if ($DisplayMessages) {
        if ($env:ARM_SUBSCRIPTION_ID -or ($(az account list --query "length([])" -o tsv) -eq 1)) {
            Write-Host "Using subscription '$(az account show --query "name" -o tsv)'"
        } else {
            if ($env:TF_IN_AUTOMATION -ine "true") {
                # Active subscription may not be the desired one, prompt the user to select one
                $subscriptions = (az account list --query "sort_by([].{id:id, name:name},&name)" -o json | ConvertFrom-Json) 
                $index = 0
                $subscriptions | Format-Table -Property @{name="index";expression={$script:index;$script:index+=1}}, id, name
                Write-Host "Set `$env:ARM_SUBSCRIPTION_ID to the id of the subscription you want to use to prevent this prompt" -NoNewline

                do {
                    Write-Host "`nEnter the index # of the subscription you want Terraform to use: " -ForegroundColor Cyan -NoNewline
                    $occurrence = Read-Host
                } while (($occurrence -notmatch "^\d+$") -or ($occurrence -lt 1) -or ($occurrence -gt $subscriptions.Length))
                $env:ARM_SUBSCRIPTION_ID = $subscriptions[$occurrence-1].id
            
                Write-Host "Using subscription '$($subscriptions[$occurrence-1].name)'" -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } else {
                Write-Host "Using subscription '$(az account show --query "name" -o tsv)', set `$env:ARM_SUBSCRIPTION_ID if you want to use another one"
            }
        }
    }

    # Populate Terraform azurerm variables where possible
    if ($userType -ine "user") {
        # Pass on pipeline service principal credentials to Terraform
        $env:ARM_CLIENT_ID       ??= $env:servicePrincipalId
        $env:ARM_CLIENT_SECRET   ??= $env:servicePrincipalKey
        $env:ARM_TENANT_ID       ??= $env:tenantId
        # Get from Azure CLI context
        $env:ARM_TENANT_ID       ??= $(az account show --query tenantId -o tsv)
        $env:ARM_SUBSCRIPTION_ID ??= $(az account show --query id -o tsv)
    }
    # Variables for Terraform azurerm Storage backend
    if (!$env:ARM_ACCESS_KEY -and !$env:ARM_SAS_TOKEN) {
        if ($env:TF_VAR_backend_storage_account -and $env:TF_VAR_backend_storage_container) {
            $env:ARM_SAS_TOKEN=$(az storage container generate-sas -n $env:TF_VAR_backend_storage_container --as-user --auth-mode login --account-name $env:TF_VAR_backend_storage_account --permissions acdlrw --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-dd") -o tsv)
        }
    }
}

function Remove-OfflineAgent (
    [parameter(Mandatory=$true)][int]$AgentId,
    [parameter(Mandatory=$true)][int]$PoolId,
    [parameter(Mandatory=$true)][string]$OrganizationUrl,
    [parameter(Mandatory=$true)][string]$Token
)
{
    "Removing agent ${AgentId} from pool $PoolId..." | Write-Host
    Write-Debug "PoolId: $PoolId"

    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/pools/${poolId}/agents/${AgentId}?api-version=${apiVersion}"
    Write-Verbose "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -Token $Token

    Write-Debug "Request JSON: $RequestJson"
    try {
        Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Delete
    } catch {
        Write-RestError
        exit 1
    }

    "Removed agent ${AgentId} from pool $PoolId" | Write-Host
}

function Remove-AgentPool (
    [parameter(Mandatory=$true)][int]$PoolId,
    [parameter(Mandatory=$true)][string]$OrganizationUrl,
    [parameter(Mandatory=$true)][string]$Token
)
{
    "Removing pool $PoolId..." | Write-Host
    Write-Debug "PoolId: $PoolId"

    $apiUrl = "${OrganizationUrl}/_apis/distributedtask/pools/${poolId}?api-version=${apiVersion}"
    Write-Verbose "REST API Url: $apiUrl"

    $requestHeaders = Create-RequestHeaders -Token $Token

    Write-Debug "Request JSON: $RequestJson"
    try {
        Invoke-RestMethod -Uri $apiUrl -Headers $requestHeaders -Method Delete
    } catch {
        Write-RestError
        exit 1
    }

    "Removed pool $PoolId" | Write-Host
}

function Set-PipelineVariablesFromTerraform () {
    $json = terraform output -json | ConvertFrom-Json -AsHashtable
    foreach ($outputVariable in $json.keys) {
        $value = $json[$outputVariable].value
        if ($value) {
            if ($value -notmatch "`n") {
                $sensitive = $json[$outputVariable].sensitive.ToString().ToLower()
                # Write variable output in the format a Pipeline can understand
                "##vso[task.setvariable variable={0};isOutput=true;issecret={2}]{1}" -f $outputVariable, $value, $sensitive  | Write-Host
                Write-Host "##vso[task.setvariable variable=${outputVariable};isOutput=true;issecret=]${value}"
            } else {
                Write-Verbose "Ignoring multi-line output variable '${outputVariable}'"
            }
        }
    }
}

function Start-ContainerEngine () {
    switch (Get-ContainerEngine) {
        "podman" {
            Start-Podman
        }
        default {
            Start-Docker
        }
    }
}

function Start-Docker () {
    Get-Process docker -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id | Set-Variable dockerProcessId

    if ($dockerProcessId) {
        Write-Host "Docker already running (pid: ${dockerProcessId})"
        return
    }
    
    if (!(Get-Command docker)) {
        Write-Warning "Docker is not installed"
        return
    }

    Write-Host "Starting Docker..."
    if ($IsLinux) {
        sudo service docker start
    }
    if ($IsMacos) {
        open -a docker
    }
    if ($IsWindows) {
        start docker
    }
    
    Write-Host "Waiting for Docker to complete startup" -NoNewline
    do {
        Start-Sleep -Milliseconds 250
        Write-Host "." -NoNewline
    } while (!$(docker stats --no-stream 2>$null))
    Write-Host "✓"
}

function Start-Podman () {
    if (!(Get-Command podman)) {
        Write-Warning "Podman is not installed"
        return
    }

    podman machine inspect | ConvertFrom-Json | Where-Object State -ieq running | Set-Variable podmanMachines
    if (!$podmanMachines) {
        Write-Host "Starting Podman..."
        podman machine start
    }
}

function Validate-ExitCode (
    [string]$cmd
) {
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Warning "'$cmd' exited with status $exitCode"
        exit $exitCode
    }
}

function Write-RestError() {
    if ($_.ErrorDetails.Message) {
        try {
            $_.ErrorDetails.Message | ConvertFrom-Json | Set-Variable restError
            $restError | Format-List | Out-String | Write-Debug
            $message = $restError.message
        } catch {
            $message = $_.ErrorDetails.Message
        }
    } else {
        $message = $_.Exception.Message
    }
    if ($message) {
        Write-Warning $message
    }
}